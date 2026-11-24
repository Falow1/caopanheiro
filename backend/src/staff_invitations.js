import { prepareTenantLinks } from './tenant_links.js';
import { requirePrincipal } from './staff_privacy.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { actor, localBackend, options, object, identifier, email, text, digest, teamAccess, tenantEnabled, tenantOpen, accountAvailable } from './runtime.js';
import { brazilPhone } from './contact_policy.js';
import { teamCommand, metadata } from './team_commands.js';
import { operationalRoles } from './workforce_policy.js';
import { pendingStaff } from './staff_invitation_policy.js';
import { staffSeatOccupied } from './manager_activation.js';
import { staffMembers } from './staff_members.js';
import { allocateRecordNumbers } from './record_numbers.js';
import { prepareProfessionalAppointments, writeProfessionalAppointments } from './professional_binding.js';

const read = (reader, db, ref) => reader === db ? ref.get() : reader.get(ref);
async function capacity(tx, db, tenant, excludeUid) {
  const [members, plan] = await Promise.all([
    staffMembers(tx, db, tenant.id),
    read(tx, db, db.doc('plans/' + identifier(tenant.get('planId'), 'Plano'))),
  ]);
  const occupied = members.docs.filter(doc => doc.id !== excludeUid && staffSeatOccupied(doc.data())).length;
  if (!plan.exists || plan.get('active') !== true || !Number.isInteger(plan.get('maxUsers')) || occupied >= plan.get('maxUsers'))
    throw new HttpsError('failed-precondition', 'Limite de usuários do plano atingido.');
}
async function professionalFor(tx, db, tenantId, id, contact, uid) {
  const doc = await read(tx, db, db.doc('tenants/' + tenantId + '/professionals/' + id));
  if (!doc.exists || doc.get('active') !== true || doc.get('email')?.toLowerCase() !== contact || doc.get('authUid') && doc.get('authUid') !== uid)
    throw new HttpsError('failed-precondition', 'Escolha um cadastro profissional ativo com o mesmo e-mail e sem vínculo com outra conta.');
  return doc;
}
export const inviteWorkforceUser = onCall(options, async () => { throw new HttpsError('failed-precondition', 'Convites agora são gerados por link, sem informar e-mail ao gestor.'); });

export const revokeWorkforceInvitation = onCall(options, async request => {
  object(request.data, ['tenantId', 'requestId', 'userId'], 'Revogação');
  const targetUid = identifier(request.data.userId, 'Usuário');
  return teamCommand(request, 'revokeWorkforceInvitation', { userId: targetUid }, async ({ tx, db, tenantId, uid }) => {
    requirePrincipal((await teamAccess(tx, db, tenantId, uid, ['MANAGER'])).member.data());
    const ref = db.doc('tenants/' + tenantId + '/members/' + targetUid), member = await tx.get(ref);
    if (!member.exists || member.get('staffInvitationPending') !== true) throw new HttpsError('failed-precondition', 'Nenhum convite operacional pendente.');
    const grouped=[];
    for(const id of member.get('invitationTenantIds')??[]) {
      if(id===tenantId)continue;
      requirePrincipal((await teamAccess(tx,db,id,uid,['MANAGER'])).member.data());
      const other=await tx.get(db.doc('tenants/'+id+'/members/'+targetUid));
      if(!other.exists||other.get('staffInvitationPending')!==true||other.get('invitationTokenHash')!==member.get('invitationTokenHash'))throw new HttpsError('failed-precondition','O convite mudou. Atualize a lista.');
      grouped.push(other);
    }
    for(const other of grouped)tx.update(other.ref,{staffInvitationPending:false,staffInvitationExpiresAt:FieldValue.delete(),...metadata(uid,true)});
    tx.update(ref, { staffInvitationPending: false, invitedRoles: FieldValue.delete(), invitedProfessionalId: FieldValue.delete(), staffInvitationExpiresAt: FieldValue.delete(), ...metadata(uid, true) });
    if (!member.get('active')) tx.delete(db.doc('users/' + targetUid + '/tenantLinks/' + tenantId));
    tx.delete(db.doc('staffInvitationOutbox/' + digest(JSON.stringify([tenantId, targetUid]))));
    tx.create(db.collection('tenants/' + tenantId + '/workforceEvents').doc(), { actorUid: uid, targetUid, action: 'INVITATION_REVOKED', createdAt: FieldValue.serverTimestamp() });
    return { userId: targetUid, revoked: true };
  }, ['MANAGER'], async ({access}) => requirePrincipal(access.member.data()));
});

export const getStaffActivation = onCall(options, async request => {
  object(request.data, [], 'Cadastro');
  const db = localBackend(), uid = await actor(request), account = await getAuth().getUser(uid);
  const links = await db.collection('users/' + uid + '/tenantLinks').limit(51).get();
  if (links.size > 50) throw new HttpsError('failed-precondition', 'Quantidade de vínculos exige revisão administrativa.');
  const companies = [];
  for (const link of links.docs) {
    const [tenant, member, subscription] = await db.getAll(db.doc('tenants/' + link.id), db.doc('tenants/' + link.id + '/members/' + uid), db.doc('subscriptions/' + link.id));
    if ((await tenantOpen(db, db, tenant, subscription)) && pendingStaff(member.data()) && member.get('email') === account.email?.toLowerCase())
      companies.push({ id: link.id, name: tenant.get('tradeName') ?? tenant.get('name'), roles: member.get('invitedRoles') });
  }
  const profile = await db.doc('users/' + uid).get();
  return { uid, email: account.email, emailVerified: account.emailVerified, name: profile.get('name') ?? account.displayName ?? '', phone: profile.get('phone') ?? '', companies };
});

export const completeStaffActivation = onCall(options, async request => {
  object(request.data, ['tenantId', 'name', 'phone'], 'Cadastro');
  const tenantId = identifier(request.data.tenantId, 'Petshop'), name = text(request.data.name, 'Nome', 100, 2), phone = brazilPhone(text(request.data.phone, 'Telefone', 32, 8));
  const db = localBackend(), uid = await actor(request), account = await getAuth().getUser(uid);
  if (!account.emailVerified) throw new HttpsError('failed-precondition', 'Confirme seu e-mail antes de aceitar o convite.');
  return db.runTransaction(async tx => {
    await accountAvailable(tx,db,uid);
    const ref = db.doc('tenants/' + tenantId + '/members/' + uid);
    const [tenant, member, subscription] = await tx.getAll(db.doc('tenants/' + tenantId), ref, db.doc('subscriptions/' + tenantId));
    if (!(await tenantOpen(tx, db, tenant, subscription)) || member.get('email') !== account.email?.toLowerCase()) throw new HttpsError('permission-denied', 'Convite indisponível para esta conta.');
    if (!member.get('staffInvitationPending') && member.get('staffActivationCompletedAt') && member.get('active') && member.get('roles')?.some(r => operationalRoles.includes(r))) return { completed: true, tenantId };
    if (!pendingStaff(member.data()) || member.get('activationPending') || member.get('roles')?.includes('MANAGER')) throw new HttpsError('failed-precondition', 'Convite expirado ou revogado. Solicite outro ao gestor.');
    await capacity(tx, db, tenant, uid);
    const roles = member.get('invitedRoles'), professionalId = member.get('invitedProfessionalId');
    const professional = roles.includes('PROFESSIONAL') ? await professionalFor(tx, db, tenantId, identifier(professionalId, 'Profissional'), account.email.toLowerCase(), uid) : null;
    const unassigned = professional ? await prepareProfessionalAppointments(tx, db, tenantId, professional.id) : [];
    const nextRoles = [...new Set([...(member.get('roles') ?? []), ...roles])];
    const writeLinks = await prepareTenantLinks(tx,db,uid,[tenantId]);
    writeLinks();
    tx.update(ref, { name, phone, roles: nextRoles, active: true, staffInvitationPending: false,
      invitedRoles: FieldValue.delete(), invitedProfessionalId: FieldValue.delete(), staffInvitationExpiresAt: FieldValue.delete(),
      ...(professional ? { professionalId: professional.id } : {}), staffActivationCompletedAt: FieldValue.serverTimestamp(), ...metadata(uid, true) });
    tx.set(db.doc('users/' + uid), { name, phone, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    tx.set(db.doc('users/' + uid + '/tenantLinks/' + tenantId), {});
    if (professional) { tx.update(professional.ref, { authUid: uid, ...metadata(uid, true) }); writeProfessionalAppointments(tx, unassigned, uid, uid); }
    tx.delete(db.doc('staffInvitationOutbox/' + digest(JSON.stringify([tenantId, uid]))));
    tx.create(db.collection('tenants/' + tenantId + '/workforceEvents').doc(), { actorUid: uid, targetUid: uid, action: 'INVITATION_ACCEPTED', roles, createdAt: FieldValue.serverTimestamp() });
    return { completed: true, tenantId };
  });
});
