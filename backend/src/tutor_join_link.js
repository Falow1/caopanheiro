import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue } from 'firebase-admin/firestore';
import { randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';
import { actor, accountAvailable, digest, identifier, invalid, localBackend, object, options, teamAccess, tenantEnabled, tenantOpen } from './runtime.js';
import { formatBrazilPhone } from './contact_policy.js';
import { metadata, teamCommand } from './team_commands.js';
import { requireManagementAction } from './management_permissions.js';
import { requirePrincipal } from './staff_privacy.js';
import { prepareTenantLinks } from './tenant_links.js';
import { prepareRecordNumbers } from './record_numbers.js';
import { tenantAudit } from './tenant_audit.js';
import { notify } from './notices.js';
import { companySuspended, tenantFeature } from './access_policy.js';

export const TEMPORARILY_UNAVAILABLE = 'Este petshop está temporariamente indisponível para novos cadastros pelo app. Fale com o petshop.';

export const TUTOR_APP_PAID = 'Link fixo, QR Code e o app do tutor ficam nos planos pagos (Essencial e Completo).';
export function requireTutorApp(subscription) {
  if (!tenantFeature(subscription, 'tutorApp')) throw new HttpsError('failed-precondition', TUTOR_APP_PAID, { reason: 'PLAN_FEATURE' });
}

// Fixed petshop link: an open Tutor invitation, one per petshop, meant to be
// shown at the counter or posted. Its secret is kept readable so the manager
// can always show the same link, QR Code and poster; it grants no reading of
// any data. Code format: `tenantId.token` (the individual invite has 3 parts).
export const JOIN_DAILY_LIMIT = 200;
const TOKEN = /^[A-Za-z0-9_-]{43}$/;
const newToken = () => randomBytes(32).toString('base64url');
const linkRef = (db, tenantId) => db.doc(`tenants/${tenantId}/tutorJoinLinks/current`);
const requestRef = (db, tenantId, uid) => db.doc(`tenants/${tenantId}/tutorJoinRequests/${uid}`);
const utcDay = () => new Date().toISOString().slice(0, 10);
const principal = (member) => member?.active === true && member.roles?.includes('MANAGER') && member.managementDelegated !== true;
const iso = (value) => value?.toDate?.().toISOString() ?? null;

function sameToken(stored, given) {
  if (typeof stored !== 'string') return false;
  return timingSafeEqual(Buffer.from(digest(stored), 'hex'), Buffer.from(digest(given), 'hex'));
}

/// Name and phone for a record created from the account; null when the
/// account does not have both in the formats the team form accepts; the
/// phone is saved formatted, like the one the team types.
function accountContact(user, profile) {
  const trimmed = (value) => typeof value === 'string' ? value.trim() : '';
  const name = trimmed(profile.get('name')) || trimmed(user.displayName);
  const phone = trimmed(profile.get('phone')) || trimmed(user.phoneNumber);
  const formatted = formatBrazilPhone(phone);
  if (name.length < 2 || name.length > 100 || !formatted) return null;
  return { name, phone: formatted };
}

const entryRefusals = {
  taken: ['permission-denied', 'Este e-mail já tem acesso por outra conta neste petshop. Fale com o petshop.'],
  repeated: ['failed-precondition', 'Há mais de um cadastro com este e-mail neste petshop. Peça um convite individual ao petshop.'],
  contact: ['failed-precondition', 'Informe seu nome e telefone para concluir o cadastro.'],
};
const approvalRefusals = {
  taken: ['failed-precondition', 'O e-mail desta conta já está ligado a outra conta neste petshop.'],
  repeated: ['failed-precondition', 'Há mais de um cadastro com o e-mail desta conta. Use o convite individual no cadastro certo.'],
  contact: ['failed-precondition', 'A conta não tem nome e telefone para criar o cadastro. Peça ao tutor para abrir o link de novo.'],
};
const refuse = ([code, message]) => { throw new HttpsError(code, message); };

/// Read phase: the record of the same e-mail still without an account, or a
/// new record from the account's own contact. Never picks among duplicates.
async function resolveRecord(tx, db, tenantId, email, user, profile, refusals) {
  const page = await tx.get(db.collection(`tenants/${tenantId}/customers`).where('email', '==', email).limit(3));
  const free = page.docs.filter((doc) => !doc.get('tutorUid'));
  if (free.length > 1) refuse(refusals.repeated);
  if (free.length === 1) return { customer: free[0], contact: null };
  if (page.size) refuse(refusals.taken);
  const contact = accountContact(user, profile);
  if (!contact) refuse(refusals.contact);
  return { customer: null, contact };
}

/// Read phase of the Tutor link shared by the fixed link and the approved
/// return; the returned writer must run only after all reads.
async function prepareTutorLink(tx, db, { tenantId, uid, member, customer, contact, email, actorUid }) {
  const customerId = customer?.id ?? 'c' + randomUUID().replaceAll('-', '');
  const writeLinks = await prepareTenantLinks(tx, db, uid, [tenantId]);
  const numbers = await prepareRecordNumbers(tx, db, tenantId, [
    { type: 'members', id: uid, recordNumber: member.get('recordNumber') },
    ...(customer ? [] : [{ type: 'customers', id: customerId }]),
  ]);
  const name = customer?.get('name') ?? contact.name;
  return { customerId, name, write() {
    writeLinks(); numbers.write();
    const ref = db.doc(`tenants/${tenantId}/customers/${customerId}`);
    if (customer) tx.update(ref, { tutorUid: uid, tutorUnlinkedAt: FieldValue.delete(), ...metadata(actorUid, true) });
    else tx.create(ref, { name: contact.name, phone: contact.phone, email, recordNumber: numbers.numbers[1], pets: {}, tutorUid: uid, origin: 'JOIN_LINK', ...metadata(actorUid, false) });
    // Team roles of the same account are kept; only TUTOR is added.
    tx.set(member.ref, { recordNumber: numbers.numbers[0], active: true, tutorUnlinkedAt: FieldValue.delete(), roles: FieldValue.arrayUnion('TUTOR'), customerId, name: member.get('name') ?? name }, { merge: true });
    tx.set(db.doc(`users/${uid}/tenantLinks/${tenantId}`), { active: true, customerId }, { merge: true });
  } };
}

/// Entry through the fixed link, called by acceptTutorLink for 2-part codes.
export async function joinTutorLink(db, uid, parts) {
  const tenantId = identifier(parts[0], 'Empresa');
  if (!TOKEN.test(parts[1])) invalid('Código inválido.');
  const token = parts[1], user = await getAuth().getUser(uid);
  if (!user.emailVerified || !user.email) throw new HttpsError('failed-precondition', 'Confirme o e-mail da sua conta antes de vincular.');
  const email = user.email.toLowerCase();
  return db.runTransaction(async (tx) => {
    await accountAvailable(tx, db, uid);
    const tenantRef = db.doc(`tenants/${tenantId}`), memberRef = tenantRef.collection('members').doc(uid);
    const [tenant, subscription, link, member, profile, pending] = await tx.getAll(tenantRef, db.doc(`subscriptions/${tenantId}`),
      linkRef(db, tenantId), memberRef, db.doc('users/' + uid), requestRef(db, tenantId, uid));
    const linkValid = link.exists && link.get('active') === true && sameToken(link.get('token'), token);
    const open = await tenantOpen(tx, db, tenant, subscription);
    // A valid link of a paused petshop (platform suspension or E2 block) says
    // so, instead of looking removed; the reason is never shown.
    if (linkValid && !open && tenant.exists && (companySuspended(tenant.data()) || tenantEnabled(tenant, subscription)))
      throw new HttpsError('failed-precondition', TEMPORARILY_UNAVAILABLE, { reason: 'TEMPORARILY_UNAVAILABLE' });
    if (!open || !linkValid)
      throw new HttpsError('permission-denied', 'Link de convite inválido ou desativado. Peça o link atual ao petshop.');
    if (!tenantFeature(subscription, 'tutorApp')) throw new HttpsError('permission-denied', 'Este petshop não está recebendo novos clientes pelo app no momento. Fale com o petshop.', { reason: 'TUTOR_APP_UNAVAILABLE' });
    const value = member.data() ?? {};
    if (value.active === true && value.roles?.includes('TUTOR') && value.customerId) {
      const current = await tx.get(tenantRef.collection('customers').doc(identifier(value.customerId, 'Cliente')));
      if (current.exists && current.get('tutorUid') === uid) return { tenantId, customerId: current.id };
      throw new HttpsError('permission-denied', 'Vínculo não permitido.');
    }
    if (pending.get('status') === 'REFUSED') throw new HttpsError('permission-denied', 'O petshop não liberou este acesso. Fale com o petshop.');
    const unlinked = member.exists && value.tutorUnlinkedAt != null;
    // An inactive membership without the explicit unlink mark is never reopened here.
    if (member.exists && value.active !== true && !unlinked) throw new HttpsError('permission-denied', 'Vínculo não permitido.');
    const { customer, contact } = await resolveRecord(tx, db, tenantId, email, user, profile, entryRefusals);
    const name = customer?.get('name') ?? contact.name;
    if (unlinked || customer?.get('tutorUnlinkedAt') != null) {
      // Unlinked by this petshop: the principal manager decides the return.
      if (!pending.exists) {
        tx.create(requestRef(db, tenantId, uid), { uid, customerId: customer?.id ?? null, status: 'PENDING', requestedAt: FieldValue.serverTimestamp() });
        notify(tx, db, tenantId, uid, [{ role: 'TEAM', type: 'TUTOR_RETURN_REQUESTED', title: 'Pedido de retorno',
          text: `${name} pediu para voltar a usar o app neste petshop. O gestor principal aprova ou recusa em Mais, Link de convite.` }]);
      }
      return { tenantId, pending: true };
    }
    const day = utcDay(), count = link.get('day') === day && Number.isSafeInteger(link.get('dayCount')) ? link.get('dayCount') : 0;
    if (count >= JOIN_DAILY_LIMIT) throw new HttpsError('resource-exhausted', 'Muitos cadastros por este link hoje. Tente amanhã ou peça um convite ao petshop.');
    const prepared = await prepareTutorLink(tx, db, { tenantId, uid, member, customer, contact, email, actorUid: uid });
    prepared.write();
    tx.update(link.ref, { day, dayCount: count + 1 });
    if (pending.exists) tx.delete(pending.ref);
    tx.create(tenantRef.collection('workforceEvents').doc(), { action: 'TUTOR_JOINED_BY_LINK', actorUid: uid, targetUid: uid, customerId: prepared.customerId, createdAt: FieldValue.serverTimestamp() });
    notify(tx, db, tenantId, uid, [{ role: 'TEAM', type: 'TUTOR_JOINED', title: 'Novo tutor pelo link', text: `${name} entrou no app pelo link de convite do petshop.` }]);
    return { tenantId, customerId: prepared.customerId };
  });
}

/// Shows the petshop link, creating it the first time a manager opens the
/// area. Return requests travel only to the principal manager, with name and
/// e-mail read now from the account: the request keeps no personal data.
export const getTutorJoinLink = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  object(request.data, ['tenantId'], 'Consulta');
  const tenantId = identifier(request.data.tenantId, 'Empresa');
  const state = await db.runTransaction(async (tx) => {
    const access = await teamAccess(tx, db, tenantId, uid, ['MANAGER']);
    requireManagementAction(access.member.data(), 'getTutorJoinLink');
    requireTutorApp(access.subscription);
    const isPrincipal = principal(access.member.data()), ref = linkRef(db, tenantId), link = await tx.get(ref);
    const page = isPrincipal ? await tx.get(db.collection(`tenants/${tenantId}/tutorJoinRequests`).where('status', '==', 'PENDING').limit(51)) : null;
    let token = link.get('token'), active = link.get('active') === true;
    if (!link.exists) {
      token = newToken(); active = true;
      tx.create(ref, { token, active, createdAt: FieldValue.serverTimestamp(), createdBy: uid, day: null, dayCount: 0 });
    }
    const rows = (page?.docs ?? []).slice(0, 50).map((doc) => ({ uid: doc.id, customerId: doc.get('customerId') ?? null, requestedAt: iso(doc.get('requestedAt')) }));
    return { token, active, isPrincipal, rows, more: (page?.size ?? 0) > 50 };
  });
  const requests = [];
  if (state.rows.length) {
    const { users } = await getAuth().getUsers(state.rows.map((row) => ({ uid: row.uid })));
    const accounts = new Map(users.map((user) => [user.uid, user]));
    const profiles = await db.getAll(...state.rows.map((row) => db.doc('users/' + row.uid)));
    const customerIds = [...new Set(state.rows.map((row) => row.customerId).filter((id) => typeof id === 'string'))];
    const records = customerIds.length ? await db.getAll(...customerIds.map((id) => db.doc(`tenants/${tenantId}/customers/${identifier(id, 'Cliente')}`))) : [];
    const names = new Map(records.filter((doc) => doc.exists).map((doc) => [doc.id, doc.get('name') ?? null]));
    const gone = [];
    state.rows.forEach((row, index) => {
      const user = accounts.get(row.uid), profile = profiles[index];
      if (!user || profile.get('deletionState')) { gone.push(row.uid); return; }
      const own = profile.get('name');
      requests.push({ ...row, name: typeof own === 'string' && own.trim() ? own.trim() : user.displayName ?? '', email: user.email ?? '', customerName: names.get(row.customerId) ?? null });
    });
    // A deleted account leaves no request behind.
    if (gone.length) { const batch = db.batch(); for (const id of gone) batch.delete(requestRef(db, tenantId, id)); await batch.commit(); }
    requests.sort((a, b) => (a.requestedAt ?? '').localeCompare(b.requestedAt ?? ''));
  }
  return { tenantId, code: `${tenantId}.${state.token}`, active: state.active, canManage: state.isPrincipal, requests, moreRequests: state.more };
});

const linkActions = { DISABLE: 'TUTOR_LINK_DISABLED', ENABLE: 'TUTOR_LINK_ENABLED', ROTATE: 'TUTOR_LINK_ROTATED' };
/// Principal only. The result is kept in the command receipt, so it never
/// carries the code; the app reads the link again afterwards.
export const setTutorJoinLink = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'requestId', 'action', 'confirmed'], 'Link de convite');
  const action = request.data.action;
  if (!Object.hasOwn(linkActions, action)) invalid('Ação do link inválida.');
  if (request.data.confirmed !== true) invalid('Confirme a alteração do link de convite.');
  return teamCommand(request, 'setTutorJoinLink', { action, confirmed: true }, async ({ tx, db, tenantId, uid, access }) => {
    requirePrincipal(access.member.data());
    if (action !== 'DISABLE') requireTutorApp(access.subscription);
    const ref = linkRef(db, tenantId), link = await tx.get(ref), now = FieldValue.serverTimestamp(), active = action !== 'DISABLE';
    if (!link.exists) tx.create(ref, { token: newToken(), active, createdAt: now, createdBy: uid, day: null, dayCount: 0 });
    else tx.update(ref, { active, updatedAt: now, updatedBy: uid, ...(action === 'ROTATE' ? { token: newToken(), rotatedAt: now, rotatedBy: uid } : {}) });
    tenantAudit(tx, db, tenantId, linkActions[action], uid, access.member.get('name'), {});
    return { active, rotated: action === 'ROTATE' };
  }, ['MANAGER'], async ({ access }) => requirePrincipal(access.member.data()));
});

// The account was deleted after asking to return: the request leaves the
// list. Authority is checked as for the decision itself.
async function dropRequest(request, targetUid) {
  const db = localBackend(), uid = await actor(request), tenantId = identifier(request.data.tenantId, 'Empresa');
  await db.runTransaction(async (tx) => {
    const access = await teamAccess(tx, db, tenantId, uid, ['MANAGER']);
    requirePrincipal(access.member.data());
    tx.delete(requestRef(db, tenantId, targetUid));
  });
}

/// Principal only: approving links the account again right away; refusing
/// keeps the fixed link closed to that account. The individual invite
/// remains the petshop's own way to bring the person back.
export const decideTutorReturn = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'requestId', 'targetUid', 'decision', 'confirmed'], 'Pedido de retorno');
  const targetUid = identifier(request.data.targetUid, 'Conta'), decision = request.data.decision;
  if (!['APPROVE', 'REFUSE'].includes(decision)) invalid('Decisão inválida.');
  if (request.data.confirmed !== true) invalid('Confirme a decisão sobre o pedido de retorno.');
  let user = null;
  if (decision === 'APPROVE') {
    localBackend();
    try { user = await getAuth().getUser(targetUid); } catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
    if (!user) {
      await dropRequest(request, targetUid);
      throw new HttpsError('failed-precondition', 'Esta conta não existe mais. O pedido saiu da lista.');
    }
  }
  return teamCommand(request, 'decideTutorReturn', { targetUid, decision, confirmed: true }, async ({ tx, db, tenantId, uid, access }) => {
    requirePrincipal(access.member.data());
    const pending = await tx.get(requestRef(db, tenantId, targetUid));
    if (pending.get('status') !== 'PENDING') throw new HttpsError('failed-precondition', 'Este pedido já foi decidido ou não existe mais. Atualize a lista.');
    if (decision === 'REFUSE') {
      tx.update(pending.ref, { status: 'REFUSED', decidedAt: FieldValue.serverTimestamp(), decidedBy: uid });
      tenantAudit(tx, db, tenantId, 'TUTOR_RETURN_REFUSED', uid, access.member.get('name'), { targetUid });
      return { refused: true, targetUid };
    }
    if (!user.emailVerified || !user.email) throw new HttpsError('failed-precondition', 'A conta mudou. Peça ao tutor para abrir o link de novo.');
    const memberRef = db.doc(`tenants/${tenantId}/members/${targetUid}`);
    const [member, profile] = await tx.getAll(memberRef, db.doc('users/' + targetUid));
    if (profile.get('deletionState')) throw new HttpsError('failed-precondition', 'Esta conta está em exclusão.');
    const email = user.email.toLowerCase();
    const { customer, contact } = await resolveRecord(tx, db, tenantId, email, user, profile, approvalRefusals);
    const prepared = await prepareTutorLink(tx, db, { tenantId, uid: targetUid, member, customer, contact, email, actorUid: uid });
    prepared.write();
    tx.delete(pending.ref);
    tx.create(db.collection(`tenants/${tenantId}/workforceEvents`).doc(), { action: 'TUTOR_RETURN_APPROVED', actorUid: uid, targetUid, customerId: prepared.customerId, createdAt: FieldValue.serverTimestamp() });
    tenantAudit(tx, db, tenantId, 'TUTOR_RETURN_APPROVED', uid, access.member.get('name'), { targetUid, customerId: prepared.customerId });
    notify(tx, db, tenantId, uid, [{ role: 'TUTOR', targetUid, type: 'TUTOR_RETURN_APPROVED', title: 'Retorno liberado', text: 'O petshop liberou o seu acesso de novo.' }]);
    return { approved: true, targetUid, customerId: prepared.customerId };
  }, ['MANAGER'], async ({ access }) => requirePrincipal(access.member.data()));
});
