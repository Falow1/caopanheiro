import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue } from 'firebase-admin/firestore';
import { actor, localBackend, object, options, identifier } from './runtime.js';
import { requireNoOpenAssignments } from './workforce_access.js';
import { requireNoOpenCustomerWork } from './customer_unlink.js';
import { tenantAudit } from './tenant_audit.js';
import { pendingManager } from './manager_activation.js';
import { platformCommand } from './saas.js';
import { reserveAttempt, loginPolicy, clearSuccessfulEmail } from './team_login_policy.js';
import { checkPassword } from './password_check.js';

const principalOnlyByPlatform = () => new HttpsError('failed-precondition', 'A conta do gestor principal só pode ser excluída pela administração do Cãopanheiro.');

// Read phase of an account deletion; returns the writer, or null when a previous
// deletion is only waiting for the Auth cleanup. The holder can never delete a
// principal manager account: only the platform can, through deleteManagerAccount,
// and then the petshop is left without a principal until the SaaS invites another.
async function prepareAccountDeletion(tx, db, uid, platform = null) {
  const profileRef = db.doc('users/' + uid);
  const [profile, admin] = await tx.getAll(profileRef, db.doc('platformAdmins/' + uid));
  if (admin.exists && admin.get('active') === true) throw new HttpsError('failed-precondition', 'A conta administrativa da plataforma exige transferência de responsabilidade antes da exclusão.');
  if (profile.get('deletionState')) {
    // Resume Auth cleanup, never restore access. The platform resumes only what it
    // started in this petshop; the holder's own deletion stays with the holder.
    if (platform && (!profile.get('requestedBy') || profile.get('requestedTenantId') !== platform.tenantId)) {
      throw new HttpsError('failed-precondition', 'Esta conta não tem exclusão pendente registrada pela administração neste petshop.');
    }
    return null;
  }
  // A principal deactivated by the SaaS has no profile link left, but the petshop still names them.
  const principalOf = await tx.get(db.collection('tenants').where('principalManagerUid', '==', uid).limit(51));
  if (!platform && !principalOf.empty) throw principalOnlyByPlatform();
  const links = await tx.get(profileRef.collection('tenantLinks').limit(51));
  const linked = new Set(links.docs.map(doc => doc.id));
  const tenantIds = [...new Set([...linked, ...principalOf.docs.map(doc => doc.id)])];
  if (links.size > 50 || tenantIds.length > 50) throw new HttpsError('failed-precondition', 'A quantidade de vínculos exige revisão antes de excluir a conta.');
  const changes = [];
  for (const id of tenantIds) {
    const tenantId = identifier(id, 'Petshop'), member = await tx.get(db.doc(`tenants/${tenantId}/members/${uid}`));
    const roles = member.get('roles') ?? [];
    const principal = principalOf.docs.some(doc => doc.id === tenantId) || roles.includes('MANAGER') && member.get('managementDelegated') !== true || pendingManager(member.data());
    if (principal && !platform) throw principalOnlyByPlatform();
    await requireNoOpenAssignments(tx, db, tenantId, { professionalUid: uid, professionalId: null, driverUid: uid });
    const professionals = await tx.get(db.collection(`tenants/${tenantId}/professionals`).where('authUid', '==', uid).limit(3));
    if (professionals.size > 2) throw new HttpsError('failed-precondition', 'Os cadastros profissionais exigem revisão antes da exclusão.');
    for (const pro of professionals.docs) await requireNoOpenAssignments(tx, db, tenantId, { professionalUid: null, professionalId: pro.id, driverUid: null });
    const customers = await tx.get(db.collection(`tenants/${tenantId}/customers`).where('tutorUid', '==', uid).limit(3));
    if (customers.size > 2) throw new HttpsError('failed-precondition', 'Os vínculos de cliente exigem revisão antes da exclusão.');
    for (const customer of customers.docs) await requireNoOpenCustomerWork(tx, db, tenantId, customer.id);
    changes.push({ tenantId, linked: linked.has(tenantId), member, principal, principalTenant: principalOf.docs.some(doc => doc.id === tenantId), professionals, customers });
  }
  if (platform && !changes.some(change => change.tenantId === platform.tenantId && change.principal)) {
    throw new HttpsError('failed-precondition', 'Esta conta não é de gestor principal deste petshop. As demais contas são excluídas pelo próprio titular.');
  }
  return (requestId) => {
    const actorUid = platform?.actorUid ?? uid, now = FieldValue.serverTimestamp();
    for (const { tenantId, linked: hasLink, member, principalTenant, professionals, customers } of changes) {
      if (hasLink) tx.delete(db.doc(`users/${uid}/tenantLinks/${tenantId}`));
      // deletedByPlatform keeps the record listed in the SaaS while the Auth removal is pending.
      if (member.exists) tx.update(member.ref, { active: false, roles: [], name: 'Conta excluída', email: FieldValue.delete(), phone: FieldValue.delete(), customerId: FieldValue.delete(), professionalId: FieldValue.delete(), managementDelegated: FieldValue.delete(), activationPending: false, staffInvitationPending: false, invitedRoles: FieldValue.delete(), invitedRole: FieldValue.delete(), accountDeleted: true, ...(platform?.tenantId === tenantId ? { deletedByPlatform: true } : {}), updatedAt: now });
      for (const pro of professionals.docs) tx.update(pro.ref, { active: false, authUid: FieldValue.delete(), formerAuthUid: FieldValue.delete(), name: 'Profissional removido', email: FieldValue.delete(), phone: FieldValue.delete(), updatedAt: now });
      for (const customer of customers.docs) tx.update(customer.ref, { tutorUid: null, inviteHash: FieldValue.delete(), updatedAt: now });
      if (principalTenant) tx.update(db.doc(`tenants/${tenantId}`), { principalManagerUid: FieldValue.delete(), updatedAt: now, updatedBy: actorUid });
      tx.create(db.collection(`tenants/${tenantId}/workforceEvents`).doc(), { action: platform ? 'ACCOUNT_DELETED_BY_PLATFORM' : 'ACCOUNT_DELETED', actorUid, targetUid: uid, createdAt: now });
      // The platform command writes its own audit entry; the holder's deletion is mirrored here.
      if (!platform) tenantAudit(tx, db, tenantId, 'ACCOUNT_DELETED', uid, 'Titular da conta', {});
    }
    tx.set(db.doc('users/' + uid), { deletionState: 'PENDING', requestId, requestedAt: now, ...(platform ? { requestedBy: platform.actorUid, requestedTenantId: platform.tenantId } : {}) });
  };
}

// Runs after the transaction: the identity goes last, so a failure keeps access
// blocked and the same request can resume it.
async function removeIdentity(db, uid) {
  try { await getAuth().deleteUser(uid); } catch (error) {
    if (error.code !== 'auth/user-not-found') throw new HttpsError('unavailable', 'O acesso já foi removido, mas a exclusão da identidade ainda precisa ser concluída. Tente novamente.', { reason: 'ACCOUNT_DELETION_PENDING' });
  }
  await db.doc('users/' + uid).set({ deletionState: 'COMPLETE', completedAt: FieldValue.serverTimestamp() }, { merge: true });
}

// Account deletion by the holder. Historical business records are retained;
// this is not deletion of a petshop.
export const deleteOwnAccount = onCall(options, async request => {
  object(request.data, ['requestId', 'password', 'confirmed'], 'Exclusão da própria conta');
  if (request.data.confirmed !== true) throw new HttpsError('invalid-argument', 'Confirme a exclusão da sua conta.');
  const requestId = identifier(request.data.requestId, 'Operação', 16), password = request.data.password;
  if (typeof password !== 'string' || password.length < 1 || password.length > 4096) throw new HttpsError('invalid-argument', 'Informe sua senha atual.');
  const db = localBackend(), uid = await actor(request, { allowDeleting: true }), account = await getAuth().getUser(uid);
  const attempt = await reserveAttempt(db, 'accountDeletion', account.email ?? uid, request.rawRequest.ip ?? 'unknown', loginPolicy);
  let signed;
  try {
    const response = await checkPassword(account.email, password);
    if (response.ok) signed = await response.json();
  } catch { throw new HttpsError('unavailable', 'Não foi possível confirmar sua senha.'); }
  if (signed?.localId !== uid) throw new HttpsError('failed-precondition', 'Não foi possível confirmar sua senha atual.');
  await clearSuccessfulEmail(db, attempt);
  await db.runTransaction(async tx => { const write = await prepareAccountDeletion(tx, db, uid); if (write) write(requestId); });
  await removeIdentity(db, uid);
  return { deleted: true };
});

// Deletion of a principal manager's account, exclusive to the SaaS administration.
// Same cleanup as the holder's deletion; the petshop keeps its records and is left
// without principalManagerUid, so the SaaS can invite a new principal.
export const deleteManagerAccount = onCall(options, async request => {
  object(request.data, ['requestId', 'tenantId', 'userId', 'confirmed'], 'Exclusão da conta do gestor principal');
  if (request.data.confirmed !== true) throw new HttpsError('invalid-argument', 'Confirme a exclusão da conta.');
  const tenantId = identifier(request.data.tenantId, 'Empresa'), userId = identifier(request.data.userId, 'Usuário');
  const requestId = identifier(request.data.requestId, 'Operação', 16);
  await platformCommand(request, 'deleteManagerAccount', { tenantId, userId }, async ({ tx, db, uid }) => {
    const write = await prepareAccountDeletion(tx, db, userId, { tenantId, actorUid: uid });
    if (write) write(requestId);
    return { deleted: true, userId };
  });
  await removeIdentity(localBackend(), userId);
  return { deleted: true };
});
