import { prepareTenantLinks } from './tenant_links.js';
import { INVITATION_TTL_MS, invitationValid, managerIssuedAt } from './invitation_policy.js';
import { pendingStaff } from './staff_invitation_policy.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { actor, localBackend, object, options, identifier, text, tenantEnabled, tenantOpen } from './runtime.js';
import { brazilPhone } from './contact_policy.js';
import { companyReleased } from './access_policy.js';
import { requirePrincipalAllowed } from './network_rule.js';
import { AWAITING_MANAGER, TRIAL_PLAN_ID, joinAccount, tenantMirror } from './billing_policy.js';
import { staffMembers } from './staff_members.js';

// A petshop created by the SaaS waits for its principal manager (A1-p): only
// the activation may open it, and the subscription starts there.
export function awaitingManager(tenant, subscription) {
  return tenant.exists && subscription?.exists && companyReleased(tenant.data()) && subscription.get('tenantId') === tenant.id
    && subscription.get('status') === 'PENDING' && subscription.get('pendingReason') === AWAITING_MANAGER;
}

// Pending invitations never grant operational membership. Only the canonical
// member selected below can be activated by its own verified Auth identity.
export function pendingManager(member, now = Date.now()) {
  return member?.activationPending === true
    && member?.invitedRole === 'MANAGER'
    && invitationValid(member?.activationExpiresAt,managerIssuedAt(member),now);
}

// Once a principal exists, expired principal invitations can never complete:
// close them like a revocation, keeping the link of anyone who still works there.
// Call after every read of the transaction.
export function closeExpiredManagerInvites(tx, db, tenantId, members, keepUid, actorUid, now = Date.now()) {
  for (const doc of members.docs) {
    if (doc.id === keepUid || doc.get('activationPending') !== true || doc.get('invitedRole') !== 'MANAGER' || pendingManager(doc.data(), now)) continue;
    tx.update(doc.ref, { activationPending: false, activationRevokedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), updatedBy: actorUid });
    if (doc.get('active') !== true) tx.delete(db.doc(`users/${doc.id}/tenantLinks/${tenantId}`));
  }
}

export function staffSeatOccupied(member, now = Date.now()) {
  return pendingManager(member, now) || pendingStaff(member, now) || member?.active === true && ['MANAGER','ATTENDANT','PROFESSIONAL','DRIVER'].some(role => member.roles?.includes(role));
}

export const getManagerActivation = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, [], 'Consulta');
  const account = await getAuth().getUser(uid);
  const links = await db.collection(`users/${uid}/tenantLinks`).limit(51).get();
  if (links.size > 50) throw new HttpsError('failed-precondition', 'Quantidade de vínculos requer revisão administrativa.');
  const companies = [];
  for (const link of links.docs) {
    const [tenant, member, subscription] = await db.getAll(db.doc(`tenants/${link.id}`), db.doc(`tenants/${link.id}/members/${uid}`), db.doc(`subscriptions/${link.id}`));
    if (!((await tenantOpen(db, db, tenant, subscription)) || awaitingManager(tenant, subscription)) || !pendingManager(member.data()) || member.get('email') !== account.email?.toLowerCase()) continue;
    companies.push({ id: link.id, name: tenant.get('tradeName') ?? tenant.get('name'), phone: tenant.get('phone') ?? '', city: tenant.get('city') ?? '', state: tenant.get('state') ?? '' });
  }
  const profile = await db.doc(`users/${uid}`).get();
  return { uid, email: account.email, emailVerified: account.emailVerified,
    name: profile.get('name') ?? account.displayName ?? '', phone: profile.get('phone') ?? '', companies };
});

export const completeManagerActivation = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId', 'name', 'phone', 'companyPhone', 'city', 'state'], 'Ativação');
  const tenantId = identifier(request.data.tenantId, 'Empresa');
  const name = text(request.data.name, 'Nome', 100, 2);
  const phone = brazilPhone(text(request.data.phone, 'Telefone pessoal', 30, 8));
  const companyPhone = brazilPhone(text(request.data.companyPhone, 'Telefone do petshop', 30, 8));
  const city = text(request.data.city, 'Cidade', 150, 2);
  const state = text(request.data.state, 'UF', 2, 2).toUpperCase();
  if (!['AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'].includes(state)) throw new HttpsError('invalid-argument', 'UF inválida.');
  const account = await getAuth().getUser(uid);
  if (!account.emailVerified) throw new HttpsError('failed-precondition', 'Confirme seu e-mail antes de concluir a ativação.');
  return db.runTransaction(async (tx) => {
    const ref = db.doc(`tenants/${tenantId}/members/${uid}`);
    const tenantRef = db.doc(`tenants/${tenantId}`);
    const [member, tenant, subscription] = await tx.getAll(ref, tenantRef, db.doc(`subscriptions/${tenantId}`));
    const awaiting = awaitingManager(tenant, subscription);
    if (!((await tenantOpen(tx, db, tenant, subscription)) || awaiting) || member.get('email') !== account.email?.toLowerCase()) throw new HttpsError('permission-denied', 'Convite indisponível para esta conta.');
    // A repeat after confirmed activation is harmless and cannot change fields.
    if (member.get('activationCompletedAt') && member.get('active') === true && member.get('roles')?.includes('MANAGER') && !member.get('activationPending')) return { tenantId, completed: true };
    if (!pendingManager(member.data())) throw new HttpsError('failed-precondition', 'Convite expirado ou revogado. Solicite outro ao administrador do SaaS.');
    const planId = tenant.get('planId');
    let plan = planId ? await tx.get(db.doc(`plans/${identifier(planId, 'Plano')}`)) : null;
    let billing = null;
    if (awaiting) {
      const [billingDoc, trialPlan] = await tx.getAll(db.doc(`billingAccounts/${uid}`), db.doc(`plans/${TRIAL_PLAN_ID}`));
      const accountPlan = billingDoc.exists ? await tx.get(db.doc(`plans/${identifier(billingDoc.get('planId'), 'Plano')}`)) : null;
      // Without the Completo plan registered, the trial uses the plan chosen by the SaaS.
      const trial = trialPlan.exists && trialPlan.get('active') === true ? trialPlan : plan;
      if (!trial?.exists || billingDoc.exists && !accountPlan?.exists) throw new HttpsError('failed-precondition', 'Plano indisponível. Fale com o Suporte da plataforma.');
      billing = joinAccount({ account: billingDoc.exists ? billingDoc.data() : null, uid, tenantId, tenant: tenant.data(), trialPlan: trial, accountPlan, now: Date.now() });
      billing.created = !billingDoc.exists;
      plan = billing.plan;
    }
    await requirePrincipalAllowed(tx, db, uid, tenantId);
    const members = await staffMembers(tx, db, tenantId);
    if(tenant.get('principalManagerUid') && tenant.get('principalManagerUid')!==uid || members.docs.some(d=>d.id!==uid&&d.get('active')===true&&d.get('roles')?.includes('MANAGER')&&d.get('managementDelegated')!==true))
      throw new HttpsError('failed-precondition','Este petshop já possui gestor principal. Solicite um convite de gestão delegada.');
    const occupied = members.docs.filter(d => d.id !== uid && staffSeatOccupied(d.data())).length;
    if (!plan?.exists || plan.get('active') !== true || occupied >= plan.get('maxUsers')) throw new HttpsError('failed-precondition', 'Limite de usuários do plano atingido.');
    const writeLinks = await prepareTenantLinks(tx,db,uid,[tenantId]);
    writeLinks();
    closeExpiredManagerInvites(tx, db, tenantId, members, uid, uid);
    const now = FieldValue.serverTimestamp();
    tx.set(db.doc(`users/${uid}`), { name, phone, updatedAt: now }, { merge: true });
    tx.update(ref, { name, phone, roles: [...new Set([...(member.get('roles') ?? []), 'MANAGER'])], managementDelegated: false, active: true, activationPending: false, activationCompletedAt: now, updatedAt: now, updatedBy: uid });
    tx.update(tenantRef, { principalManagerUid: uid, phone: companyPhone, city, state, ...(billing ? { planId: billing.account.planId } : {}), updatedAt: now, updatedBy: uid });
    if (billing) {
      tx.set(db.doc(`billingAccounts/${uid}`), { ...billing.account, updatedAt: now, ...(billing.created ? { createdAt: now } : {}) });
      tx.set(db.doc(`subscriptions/${tenantId}`), tenantMirror(billing.account, billing.plan, tenantId), { merge: true });
      if (billing.charge) tx.create(db.collection('billingRequests').doc(), { kind: 'CHARGE', status: 'PENDING', accountId: uid, ownerName: name,
        direction: 'CHARGE', reason: billing.charge.reason, amountCents: billing.charge.amountCents, days: billing.charge.days,
        toPlanId: billing.account.planId, toPlanName: plan.get('name') ?? billing.account.planId, tenantIds: [tenantId],
        tenantNames: [tenant.get('tradeName') ?? tenantId], createdAt: now });
    }
    tx.create(db.collection(`tenants/${tenantId}/managerActivationEvents`).doc(), { actorUid: uid, action: 'ACTIVATED', createdAt: now });
    return { tenantId, completed: true };
  });
});

export const managerInvitationExpiry = (now=Date.now()) => Timestamp.fromMillis(now + INVITATION_TTL_MS);
