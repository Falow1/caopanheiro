import { prepareTenantLinks } from './tenant_links.js';
import {prepareProfessionalAppointments,writeProfessionalAppointments} from './professional_binding.js';
import { staffSeatOccupied, managerInvitationExpiry, pendingManager, closeExpiredManagerInvites } from './manager_activation.js';
import { allocateRecordNumbers, petNumberId } from './record_numbers.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { getAuth } from 'firebase-admin/auth';
import { FieldPath, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { actor, canonical, digest, email, identifier, invalid, localBackend, object, options, text } from './runtime.js';
import { brazilPhone } from './contact_policy.js';
import { metadata } from './team_commands.js';
import { tenantOverview } from './saas_overview.js';
import { staffMembers } from './staff_members.js';
import { purgeAt, retention } from './retention.js';
import { queueManagerInvitation } from './mail_outbox.js';
import { canSkipSaasEmailCode, emailSessionValid, requireEmailSession } from './saas_email.js';
import { stateTimeZone } from './calendar.js';
import { AWAITING_MANAGER } from './billing_policy.js';

const staffRoles = ['MANAGER', 'ATTENDANT', 'PROFESSIONAL', 'DRIVER'];
const tenantStatuses = ['ACTIVE', 'ONBOARDING', 'SUSPENDED'];
const subscriptionStatuses = ['ACTIVE', 'TRIAL', 'PENDING', 'EXPIRED', 'CANCELLED'];
const choice = (value, choices, label) => { if (!choices.includes(value)) invalid(`${label} inválido.`); return value; };
const integer = (value, label, min, max) => { if (!Number.isSafeInteger(value) || value < min || value > max) invalid(`${label} inválido.`); return value; };
const iso = (value) => value?.toDate?.().toISOString() ?? null;
function jsonDoc(doc) {
  const value = doc.data();
  return { id: doc.id, ...value, createdAt: iso(value.createdAt), updatedAt: iso(value.updatedAt),
    ...(value.startedAt ? { startedAt: iso(value.startedAt) } : {}),
    ...(value.renewsAt ? { renewsAt: iso(value.renewsAt) } : {}),
    ...(value.trialEndsAt ? { trialEndsAt: iso(value.trialEndsAt) } : {}),
    ...(value.lastAt ? { lastAt: iso(value.lastAt) } : {}) };
}
async function staffAccountState(users) {
  for (let start = 0; start < users.length; start += 100) {
    const batch = users.slice(start, start + 100);
    const accounts = await getAuth().getUsers(batch.map((u) => ({ uid: u.id })));
    const byId = new Map(accounts.users.map((u) => [u.uid, u]));
    for (const user of batch) {
      const account = byId.get(user.id);
      user.lastAccess = account?.metadata.lastSignInTime ? new Date(account.metadata.lastSignInTime).toISOString() : null;
      user.accountAvailable = !!account && !account.disabled;
    }
  }
}
export async function adminAccess(reader, db, uid) {
  const [admin] = await reader.getAll(db.doc(`platformAdmins/${uid}`));
  if (!admin.exists || admin.get('active') !== true || admin.get('role') !== 'ADMIN') {
    throw new HttpsError('permission-denied', 'Acesso administrativo da plataforma obrigatório.');
  }
  return admin;
}
export async function platformCommand(request, action, normalized, apply) {
  const db = localBackend(); const uid = await actor(request);
  await requireEmailSession(request, db, uid);
  const requestId = identifier(request.data.requestId, 'Operação', 16);
  const receiptRef = db.doc(`platformCommandReceipts/${digest(JSON.stringify([uid, requestId]))}`);
  const hash = digest(JSON.stringify(canonical([action, normalized])));
  return db.runTransaction(async (tx) => {
    const admin = await adminAccess(tx, db, uid);
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.get('inputHash') !== hash) throw new HttpsError('already-exists', 'Operação já usada com outros dados.');
      return { ...receipt.get('result'), replayed: true };
    }
    const result = await apply({ tx, db, uid });
    tx.create(receiptRef, { action, actorUid: uid, inputHash: hash, result, confirmedAt: FieldValue.serverTimestamp(), purgeAt: purgeAt(retention.receipt) });
    tx.create(db.doc(`platformAudit/${receiptRef.id}`), { action, admin: admin.get('name') ?? uid, actorUid: uid,
      entity: normalized.tenantId ?? normalized.planId ?? normalized.subscriptionId ?? 'plataforma',
      tenantId: normalized.tenantId ?? null, result: 'Confirmado', reason: normalized.reason ?? null,
      details: { ...result, ...(normalized.status ? { status: normalized.status } : {}),
        ...(typeof normalized.active === 'boolean' ? { active: normalized.active } : {}), ...(normalized.planId ? { planId: normalized.planId } : {}) }, createdAt: FieldValue.serverTimestamp() });
    return { ...result, replayed: false };
  });
}
export const getSaasContext = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request); object(request.data, [], 'Consulta');
  const admin = await adminAccess(db, db, uid);
  const requiresEmailCode = !await emailSessionValid(request, db, uid);
  return { uid, requiresEmailCode, canSkipEmailCode: requiresEmailCode && canSkipSaasEmailCode(request.auth.token, admin),
    profile: { name: admin.get('name') ?? 'Administrador', email: admin.get('email') ?? '', role: 'Superadmin' } };
});
export const getSaasData = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  await requireEmailSession(request, db, uid);
  object(request.data, ['resource', 'cursor'], 'Consulta');
  // breedSuggestions: breeds people did not find on the list, by name and species only.
  const resource = choice(request.data.resource, ['tenants', 'plans', 'subscriptions', 'audit', 'breedSuggestions'], 'Consulta');
  const cursor = request.data.cursor == null ? null : identifier(request.data.cursor, 'Página');
  return db.runTransaction(async (tx) => {
    await adminAccess(tx, db, uid);
    let query = db.collection(resource === 'audit' ? 'platformAudit' : resource).orderBy(FieldPath.documentId()).limit(20);
    if (cursor) query = query.startAfter(cursor);
    const page = await tx.get(query);
    const items = [];
    for (const doc of page.docs) {
      const value = jsonDoc(doc);
      if (resource === 'tenants' && value.status === 'TRIAL') value.status = 'ACTIVE';
      if (resource === 'tenants') {
        // Bounded staff listing; do not invent usage/health metrics from fixtures.
        const members = await staffMembers(tx, db, doc.id);
        value.users = members.docs.flatMap((member) => {
          const role = staffRoles.find((role) => member.get('roles')?.includes(role)) ?? member.get('invitedRole');
          return role ? [{ id: member.id, recordNumber: member.get('recordNumber') ?? null, name: member.get('name') ?? member.id, email: member.get('email') ?? '',
            role, activationPending: member.get('activationPending') === true, active: member.get('active') === true, createdAt: iso(member.get('createdAt')) ?? value.createdAt,
            // Principal manager of this petshop: only the SaaS can delete this account.
            principal: member.id === doc.get('principalManagerUid') || member.get('roles')?.includes('MANAGER') === true && member.get('managementDelegated') !== true,
            lastAccess: null }] : [];
        });
        await staffAccountState(value.users);
        const operationalUsers = value.users.map((u) => ({ ...u, active: u.active && u.accountAvailable }));
        const overview = await tenantOverview(db, doc, operationalUsers);
        value.onboarding = overview.onboarding;
        value.metrics = overview.metrics;
        // Deletion by the SaaS whose Auth removal is still pending: listed after the
        // overview, so the administration can conclude it. Access is already blocked.
        const removed = members.docs.filter((member) => member.get('accountDeleted') === true && member.get('deletedByPlatform') === true);
        const profiles = removed.length ? await tx.getAll(...removed.map((member) => db.doc('users/' + member.id))) : [];
        profiles.forEach((profile, index) => {
          if (profile.get('deletionState') !== 'PENDING') return;
          const member = removed[index];
          value.users.push({ id: member.id, recordNumber: member.get('recordNumber') ?? null, name: member.get('name') ?? 'Conta excluída', email: '', role: 'MANAGER',
            activationPending: false, active: false, createdAt: iso(member.get('createdAt')) ?? value.createdAt, principal: false, deletionPending: true, lastAccess: null });
        });
      }
      items.push(value);
    }
    return { items, nextCursor: page.size === 20 ? page.docs.at(-1).id : null };
  });
});
export const saveTenant = onCall(options, async (request) => {
  object(request.data, ['requestId', 'tenantId', 'tenant'], 'Pedido');
  const tenantId = identifier(request.data.tenantId, 'Empresa'); const input = request.data.tenant;
  object(input, ['name', 'tradeName', 'slug', 'document', 'phone', 'email', 'city', 'state', 'responsible', 'planId'], 'Empresa');
  const value = {};
  for (const field of ['name', 'tradeName', 'document', 'phone', 'city', 'responsible']) value[field] = text(input[field], field, 150, 2);
  value.phone = brazilPhone(value.phone);
  value.state = text(input.state, 'UF', 2, 2).toUpperCase();
  value.email = email(input.email); value.slug = text(input.slug, 'Identificador público', 80, 2).toLowerCase();
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(value.slug)) invalid('Identificador público inválido.');
  value.planId = identifier(input.planId, 'Plano');
  return platformCommand(request, 'saveTenant', { tenantId, ...value }, async ({ tx, db, uid }) => {
    const ref = db.doc(`tenants/${tenantId}`); const old = await tx.get(ref);
    // A company that moves to another state follows its usual zone, unless the
    // weekly hours chose a zone other than the old state's one.
    const policyRef = db.doc(`tenants/${tenantId}/settings/scheduling`);
    const policy = old.exists && old.get('state') !== value.state ? await tx.get(policyRef) : null;
    const nextZone = stateTimeZone(value.state);
    const followZone = policy?.exists && nextZone && policy.get('timeZone') === stateTimeZone(old.get('state')) && policy.get('timeZone') !== nextZone;
    const plan = await tx.get(db.doc(`plans/${value.planId}`));
    if (!plan.exists || plan.get('active') !== true) throw new HttpsError('failed-precondition', 'Escolha um plano ativo.');
    const slugRef = db.doc(`tenantSlugs/${value.slug}`); const slug = await tx.get(slugRef);
    if (slug.exists && slug.get('tenantId') !== tenantId) throw new HttpsError('already-exists', 'Identificador público em uso.');
    const subscriptionRef = db.doc(`subscriptions/${tenantId}`); const subscription = await tx.get(subscriptionRef);
    // In the manager subscription model the plan belongs to the principal manager (A1).
    const managed = subscription.exists && !!subscription.get('accountId');
    if (managed) value.planId = subscription.get('planId');
    const [recordNumber, subscriptionNumber] = await allocateRecordNumbers(tx, db, null, [{type:'tenants',id:tenantId,recordNumber:old.get('recordNumber')},{type:'subscriptions',id:tenantId,recordNumber:subscription.get('recordNumber')}]);
    value.recordNumber=recordNumber;
    if (old.exists && old.get('slug') && old.get('slug') !== value.slug) tx.delete(db.doc(`tenantSlugs/${old.get('slug')}`));
    tx.set(slugRef, { tenantId });
    if (followZone) tx.update(policyRef, { timeZone: nextZone, ...metadata(uid, true) });
    tx.set(ref, { ...value, ...metadata(uid, old.exists), ...(!old.exists ? { status: 'ACTIVE' } : {}) }, { merge: true });
    // A new petshop waits for its principal manager: the 30-day trial starts at the activation (A1-p).
    if (!subscription.exists) tx.create(subscriptionRef, { recordNumber: subscriptionNumber, tenantId, planId: value.planId, status: 'PENDING', pendingReason: AWAITING_MANAGER, ...metadata(uid, false) });
    else tx.update(subscriptionRef, { recordNumber: subscriptionNumber, planId: value.planId, ...metadata(uid, true) });
    return { tenantId, recordNumber, subscriptionNumber };
  });
});
/// The platform read the suggestion (and added the breed to the list, or not).
export const removeBreedSuggestion = onCall(options, async (request) => {
  object(request.data, ['requestId', 'suggestionId'], 'Pedido');
  const suggestionId = identifier(request.data.suggestionId, 'Sugestão');
  return platformCommand(request, 'removeBreedSuggestion', { suggestionId }, async ({ tx, db }) => {
    const ref = db.doc(`breedSuggestions/${suggestionId}`); const old = await tx.get(ref);
    if (old.exists) tx.delete(ref);
    return { suggestionId, removed: old.exists };
  });
});
export const setTenantStatus = onCall(options, async (request) => {
  object(request.data, ['requestId', 'tenantId', 'status', 'reason'], 'Pedido');
  const tenantId = identifier(request.data.tenantId, 'Empresa'); const status = choice(request.data.status, tenantStatuses, 'Situação');
  const reason = text(request.data.reason ?? '', 'Motivo', 1000, status === 'SUSPENDED' ? 3 : 0);
  return platformCommand(request, 'setTenantStatus', { tenantId, status, reason }, async ({ tx, db, uid }) => {
    const ref = db.doc(`tenants/${tenantId}`); const old = await tx.get(ref);
    if (!old.exists) throw new HttpsError('not-found', 'Empresa indisponível.');
    tx.update(ref, { status, suspensionReason: reason, ...metadata(uid, true) }); return { tenantId, beforeStatus: old.get('status'), afterStatus: status };
  });
});
export const savePlan = onCall(options, async (request) => {
  object(request.data, ['requestId', 'planId', 'plan'], 'Pedido'); const planId = identifier(request.data.planId, 'Plano'); const input = request.data.plan;
  object(input, ['name', 'description', 'monthlyPriceCents', 'maxProfessionals', 'maxUsers', 'features', 'active'], 'Plano');
  if (typeof input.active !== 'boolean' || !Array.isArray(input.features) || input.features.length > 50) invalid('Plano inválido.');
  const value = { name: text(input.name, 'Nome', 100, 2), description: text(input.description, 'Descrição', 2000),
    monthlyPriceCents: integer(input.monthlyPriceCents, 'Preço', 0, 100000000), maxProfessionals: integer(input.maxProfessionals, 'Profissionais', 1, 100),
    maxUsers: integer(input.maxUsers, 'Usuários', 1, 500), features: input.features.map((item) => text(item, 'Recurso', 150, 1)), active: input.active };
  return platformCommand(request, 'savePlan', { planId, ...value }, async ({ tx, db, uid }) => {
    const ref = db.doc(`plans/${planId}`); const old = await tx.get(ref);
    const [recordNumber]=await allocateRecordNumbers(tx,db,null,[{type:'plans',id:planId,recordNumber:old.get('recordNumber')}]);
    tx.set(ref, { ...value, recordNumber, ...metadata(uid, old.exists) }, { merge: true }); return { planId, recordNumber };
  });
});
export const updateSubscription = onCall(options, async (request) => {
  object(request.data, ['requestId', 'subscriptionId', 'planId', 'status'], 'Pedido');
  const subscriptionId = identifier(request.data.subscriptionId, 'Assinatura'); const planId = identifier(request.data.planId, 'Plano');
  const status = choice(request.data.status, subscriptionStatuses, 'Situação');
  return platformCommand(request, 'updateSubscription', { subscriptionId, planId, status }, async ({ tx, db, uid }) => {
    const ref = db.doc(`subscriptions/${subscriptionId}`); const subscription = await tx.get(ref); const plan = await tx.get(db.doc(`plans/${planId}`));
    if (!subscription.exists || !plan.exists || plan.get('active') !== true) throw new HttpsError('failed-precondition', 'Assinatura ou plano indisponível.');
    if (subscription.get('accountId')) throw new HttpsError('failed-precondition', 'Esta assinatura é do gestor principal. Use os pedidos em Pendências.');
    const tenantRef = db.doc(`tenants/${identifier(subscription.get('tenantId'), 'Empresa')}`); const tenant = await tx.get(tenantRef);
    if (!tenant.exists) throw new HttpsError('not-found', 'Empresa indisponível.');
    if (status === 'TRIAL' && (!subscription.get('renewsAt') || subscription.get('renewsAt').toMillis() <= Date.now())) throw new HttpsError('failed-precondition', 'Trial encerrado.');
    tx.update(ref, { planId, status, ...metadata(uid, true) });
    // This is an administrative state, without automatic billing or payments.
    tx.update(tenantRef, { planId, ...metadata(uid, true) });
    return { subscriptionId };
  });
});
export const saveTenantMember = onCall(options, async (request) => {
  object(request.data, ['requestId', 'tenantId', 'name', 'email', 'role'], 'Pedido');
  const tenantId = identifier(request.data.tenantId, 'Empresa'); const name = text(request.data.name, 'Nome', 100, 2); const contact = email(request.data.email);
  const role = choice(request.data.role, staffRoles, 'Papel');
  if (role === 'MANAGER') return inviteManager(request, tenantId, name, contact);
  const db = localBackend(); const uid = await actor(request); await adminAccess(db, db, uid);
  let account; try { account = await getAuth().getUserByEmail(contact); } catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
  if (!account || account.disabled || !account.emailVerified) throw new HttpsError('failed-precondition', 'A pessoa precisa criar uma conta e verificar seu e-mail antes do vínculo.');
  return platformCommand(request, 'saveTenantMember', { tenantId, name, email: contact, role, accountUid: account.uid }, async ({ tx, db, uid }) => {
    const tenant = await tx.get(db.doc(`tenants/${tenantId}`)); if (!tenant.exists) throw new HttpsError('not-found', 'Empresa indisponível.');
    const ref = db.doc(`tenants/${tenantId}/members/${account.uid}`); const previous = await tx.get(ref);
    if (previous.get('staffInvitationPending')) throw new HttpsError('failed-precondition', 'O usuário precisa aceitar o convite operacional ou o gestor deve revogá-lo antes de alterar este acesso.');
    const members = await staffMembers(tx, db, tenantId);
    const plan = await tx.get(db.doc(`plans/${identifier(tenant.get('planId'), 'Plano')}`));
    const staffCount = members.docs.filter((doc) => doc.id !== account.uid && staffSeatOccupied(doc.data())).length;
    if ((!previous.exists || previous.get('active') !== true || !staffRoles.some((role) => previous.get('roles')?.includes(role))) && (!plan.exists || staffCount >= plan.get('maxUsers'))) throw new HttpsError('failed-precondition', 'Limite de usuários do plano atingido.');
    const professionals = role === 'PROFESSIONAL' ? await tx.get(db.collection(`tenants/${tenantId}/professionals`).where('email', '==', contact).limit(2)) : null;
    if (professionals && (professionals.size !== 1 || professionals.docs[0].get('active') !== true || (professionals.docs[0].get('authUid') && professionals.docs[0].get('authUid') !== account.uid))) throw new HttpsError('failed-precondition', 'Cadastre um único profissional ativo com este e-mail na empresa.');
    const unassigned = professionals ? await prepareProfessionalAppointments(tx,db,tenantId,professionals.docs[0].id) : [];
    const roles = [...new Set([...(previous.get('roles') ?? []), role])];
    const writeLinks=await prepareTenantLinks(tx,db,account.uid,[tenantId]);
    const [recordNumber]=await allocateRecordNumbers(tx,db,tenantId,[{type:'members',id:account.uid,recordNumber:previous.get('recordNumber')}]);
    writeLinks();
    tx.set(ref, { recordNumber, name, email: contact, roles, active: true, ...metadata(uid, previous.exists), ...(professionals ? { professionalId: professionals.docs[0].id } : {}) }, { merge: true });
    if(professionals)writeProfessionalAppointments(tx,unassigned,account.uid,uid);
    if (professionals) tx.update(professionals.docs[0].ref, { authUid: account.uid, ...metadata(uid, true) });
    tx.set(db.doc(`users/${account.uid}/tenantLinks/${tenantId}`), {}); return { tenantId, userId: account.uid };
  });
});
export const setTenantUserActive = onCall(options, async (request) => {
  object(request.data, ['requestId', 'tenantId', 'userId', 'active'], 'Pedido');
  const tenantId = identifier(request.data.tenantId, 'Empresa'); const userId = identifier(request.data.userId, 'Usuário'); const active = request.data.active;
  if (typeof active !== 'boolean') invalid('Situação inválida.');
  return platformCommand(request, 'setTenantUserActive', { tenantId, userId, active }, async ({ tx, db, uid }) => {
    const ref = db.doc(`tenants/${tenantId}/members/${userId}`); const member = await tx.get(ref);
    if (!member.exists || !(member.get('activationPending') || staffRoles.some((role) => member.get('roles')?.includes(role)))) throw new HttpsError('not-found', 'Usuário da equipe indisponível.');
    if (member.get('staffInvitationPending')) throw new HttpsError('failed-precondition', 'O convite operacional precisa ser aceito pelo destinatário ou revogado pelo gestor.');
    if (active && member.get('activationPending')) throw new HttpsError('failed-precondition', 'O gestor precisa concluir o primeiro acesso.');
    if (!active && member.get('activationPending')) {
      // Revoking a promotion must not remove an existing attendant/other role.
      tx.update(ref, { activationPending: false, activationRevokedAt: FieldValue.serverTimestamp(), ...metadata(uid, true) });
      if (member.get('active') !== true) tx.delete(db.doc(`users/${userId}/tenantLinks/${tenantId}`));
      return { tenantId, userId, invitationRevoked: true };
    }
    const tenant = await tx.get(db.doc(`tenants/${tenantId}`));
    const members = await staffMembers(tx, db, tenantId);
    const plan = tenant.get('planId') ? await tx.get(db.doc(`plans/${identifier(tenant.get('planId'), 'Plano')}`)) : null;
    if(active && member.get('roles')?.includes('MANAGER') && member.get('managementDelegated')!==true && (tenant.get('principalManagerUid') && tenant.get('principalManagerUid')!==userId || members.docs.some(d=>d.id!==userId && (pendingManager(d.data()) || d.get('active')===true&&d.get('roles')?.includes('MANAGER')&&d.get('managementDelegated')!==true))))throw new HttpsError('failed-precondition','Este petshop já possui gestor principal ou convite principal.');
    if (active && member.get('active') !== true && (!plan?.exists || members.docs.filter((doc) => staffSeatOccupied(doc.data())).length >= plan.get('maxUsers'))) throw new HttpsError('failed-precondition', 'Limite do plano atingido.');
    if (active) { const writeLinks = await prepareTenantLinks(tx,db,userId,[tenantId]); writeLinks(); }
    if (active && member.get('roles')?.includes('MANAGER') && member.get('managementDelegated')!==true) closeExpiredManagerInvites(tx, db, tenantId, members, userId, uid);
    // Legacy petshops have no principalManagerUid: record it before the profile link goes,
    // so the principal keeps the protections that depend on it (account deletion included).
    if (tenant.exists && !tenant.get('principalManagerUid') && member.get('roles')?.includes('MANAGER') && member.get('managementDelegated') !== true
      && !members.docs.some((d) => d.id !== userId && d.get('active') === true && d.get('roles')?.includes('MANAGER') && d.get('managementDelegated') !== true)) {
      tx.update(tenant.ref, { principalManagerUid: userId, updatedAt: FieldValue.serverTimestamp(), updatedBy: uid });
    }
    tx.update(ref, { active, ...(!active ? { activationPending: false } : {}), ...metadata(uid, true) });
    const link = db.doc(`users/${userId}/tenantLinks/${tenantId}`); if (active) tx.set(link, {}); else tx.delete(link);
    return { tenantId, userId };
  });
});

export const getSaasDiagnostics = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  await requireEmailSession(request, db, uid);
  object(request.data, ['tenantId', 'requestId', 'reason'], 'Diagnóstico');
  const tenantId = identifier(request.data.tenantId, 'Empresa');
  const reason = text(request.data.reason, 'Motivo', 1000, 3);
  await adminAccess(db, db, uid);
  const tenant = await db.doc(`tenants/${tenantId}`).get();
  if (!tenant.exists) throw new HttpsError('not-found', 'Empresa indisponível.');
  const members = await staffMembers(db, db, tenantId);
  const users = members.docs.map((m) => ({ id: m.id, active: m.get('active') === true, role: staffRoles.find((r) => m.get('roles')?.includes(r)) }));
  await staffAccountState(users);
  const overview = await tenantOverview(db, tenant, users.map((u) => ({ ...u, active: u.active && u.accountAvailable })));
  const subscription = await db.doc(`subscriptions/${tenantId}`).get();
  const result = { tenantId, checkedAt: new Date().toISOString(), onboarding: overview.onboarding,
    metrics: overview.metrics, tenantStatus: tenant.get('status') === 'TRIAL' ? 'ACTIVE' : tenant.get('status'), subscriptionStatus: subscription.get('status') ?? null };
  await platformCommand(request, 'Diagnóstico de suporte', { tenantId, reason }, async () => ({ tenantId }));
  return result;
});


async function inviteManager(request, tenantId, name, contact) {
  const db = localBackend(); const uid = await actor(request);
  await adminAccess(db, db, uid); await requireEmailSession(request, db, uid);
  identifier(request.data.requestId, 'Operação', 16);
  // Validate the destination before creating an Auth identity. Auth and
  // Firestore do not share a transaction; a retry reuses the email identity.
  const tenant = await db.doc(`tenants/${tenantId}`).get();
  if (!tenant.exists) throw new HttpsError('not-found', 'Empresa indisponível.');
  const plan = await db.doc(`plans/${identifier(tenant.get('planId'), 'Plano')}`).get();
  if (!plan.exists || !plan.get('active')) throw new HttpsError('failed-precondition', 'Plano indisponível.');
  let account;
  try { account = await getAuth().getUserByEmail(contact); }
  catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    try { account = await getAuth().createUser({ email: contact, displayName: name }); }
    catch (creation) {
      if (creation.code !== 'auth/email-already-exists') throw creation;
      account = await getAuth().getUserByEmail(contact);
    }
  }
  if (account.disabled) throw new HttpsError('failed-precondition', 'Conta desativada.');
  const receipt = await db.doc(`platformCommandReceipts/${digest(JSON.stringify([uid, request.data.requestId]))}`).get();
  const resetLink = !receipt.exists && !account.emailVerified ? await getAuth().generatePasswordResetLink(contact) : null;
  return platformCommand(request, 'saveTenantMember', { tenantId, name, email: contact, role: 'MANAGER', accountUid: account.uid }, async ({ tx, db, uid }) => {
    const tenantRef = db.doc(`tenants/${tenantId}`);
    const current = await tx.get(tenantRef);
    if (!current.exists) throw new HttpsError('not-found', 'Empresa indisponível.');
    const ref = tenantRef.collection('members').doc(account.uid); const previous = await tx.get(ref);
    if (previous.get('staffInvitationPending')) throw new HttpsError('failed-precondition', 'Revogue ou conclua o convite operacional antes de convidar como gestor.');
    if (previous.get('active') === true && previous.get('roles')?.includes('MANAGER')) return { tenantId, userId: account.uid, activationPending: false };
    const members = await staffMembers(tx, db, tenantId);
    // Only a valid principal invitation blocks another one; an expired one can no longer be completed.
    if(current.get('principalManagerUid') && current.get('principalManagerUid')!==account.uid || members.docs.some(d=>d.id!==account.uid && (pendingManager(d.data()) || d.get('active')===true&&d.get('roles')?.includes('MANAGER')&&d.get('managementDelegated')!==true)))
      throw new HttpsError('failed-precondition','Este petshop já tem gestor principal ou convite principal. Outros gestores devem ser convidados pelo principal no app Equipe.');
    const currentPlan = await tx.get(db.doc(`plans/${identifier(current.get('planId'), 'Plano')}`));
    const count = members.docs.filter(d => d.id !== account.uid && staffSeatOccupied(d.data())).length;
    if (!currentPlan.exists || !currentPlan.get('active') || count >= currentPlan.get('maxUsers')) throw new HttpsError('failed-precondition', 'Limite de usuários do plano atingido.');
    const writeLinks = await prepareTenantLinks(tx,db,account.uid,[tenantId]);
    const [recordNumber] = await allocateRecordNumbers(tx, db, tenantId, [{type:'members',id:account.uid,recordNumber:previous.get('recordNumber')}]);
    writeLinks();
    closeExpiredManagerInvites(tx, db, tenantId, members, account.uid, uid);
    const issuedAt=Timestamp.now(),expiresAt = managerInvitationExpiry(issuedAt.toMillis());
    tx.set(ref, { recordNumber, name, email: contact, roles: previous.get('roles') ?? [], active: previous.get('active') === true,
      activationIssuedAt: issuedAt, activationPending: true, invitedRole: 'MANAGER', activationExpiresAt: expiresAt, ...metadata(uid, previous.exists) }, { merge: true });
    tx.set(db.doc(`users/${account.uid}/tenantLinks/${tenantId}`), {});
    // Private local mailbox, following the existing SaaS email outbox pattern.
    // No email delivery, password or action link is returned to the admin app.
    queueManagerInvitation(tx, db, digest(JSON.stringify([tenantId, account.uid])), {
      tenantId, recipientUid: account.uid, email: contact, companyName: current.get('tradeName') ?? current.get('name'),
      subject: 'Ative seu acesso de gestor ao Cãopanheiro',
      message: resetLink ? 'Defina sua senha pelo link e entre com seu e-mail no app Equipe.' : 'Entre com seu e-mail e senha atual no app Equipe para completar o cadastro. Sua senha não foi alterada.',
      resetLink, expiresAt, delivery: 'LOCAL_ONLY', createdAt: FieldValue.serverTimestamp(), createdBy: uid });
    return { tenantId, userId: account.uid, activationPending: true };
  });
}
