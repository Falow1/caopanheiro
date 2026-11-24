import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { actor, identifier, invalid, localBackend, object, options, teamAccess, text } from './runtime.js';
import { teamCommand } from './team_commands.js';
import { adminAccess, platformCommand } from './saas.js';
import { requireEmailSession } from './saas_email.js';
import { notify } from './notices.js';

// Support requests go from the managers of a petshop to the platform
// administration. Messages stay inside the applications: no e-mail is sent.
const MAX_OPEN = 10; const MAX_MESSAGES = 50; const PAGE = 100;
const openStatuses = ['OPEN', 'ANSWERED'];
const requestRef = (db, id) => db.doc(`supportRequests/${id}`);
const cursorValue = (data) => data.cursor == null ? null : identifier(data.cursor, 'Página');

/// Runs a page of the query in the transaction. The cursor is the id of the
/// last request already shown; a cursor from another petshop is refused.
async function page(tx, db, query, cursor, tenantId = null) {
  let paged = query.limit(PAGE);
  if (cursor) {
    const last = await tx.get(requestRef(db, cursor));
    if (!last.exists || (tenantId && last.get('tenantId') !== tenantId)) invalid('Página inválida.');
    paged = paged.startAfter(last);
  }
  const result = await tx.get(paged);
  return { items: result.docs.map(json), nextCursor: result.size === PAGE ? result.docs.at(-1).id : null };
}
function json(doc) {
  const value = doc.data();
  return { id: doc.id, tenantId: value.tenantId, tenantName: value.tenantName ?? value.tenantId, authorName: value.authorName ?? '',
    subject: value.subject, message: value.message, status: value.status, createdAt: value.createdAt, updatedAt: value.updatedAt ?? value.createdAt,
    replies: (value.replies ?? []).map((reply) => ({ from: reply.from, authorName: reply.authorName ?? '', message: reply.message, at: reply.at })) };
}

export const createSupportRequest = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'requestId', 'subject', 'message'], 'Pedido de suporte');
  const subject = text(request.data.subject, 'Assunto', 120, 3); const message = text(request.data.message, 'Mensagem', 2000, 10);
  return teamCommand(request, 'createSupportRequest', { subject, message }, async ({ db, tx, tenantId, uid, access }) => {
    // Only requests still open count: closed ones never block a new request.
    const open = await tx.get(db.collection('supportRequests').where('tenantId', '==', tenantId)
      .where('status', 'in', openStatuses).limit(MAX_OPEN));
    if (open.size >= MAX_OPEN) throw new HttpsError('resource-exhausted', 'Há muitos pedidos de suporte abertos. Aguarde a resposta ou acrescente a mensagem em um pedido existente.');
    const ref = db.collection('supportRequests').doc(); const now = new Date().toISOString();
    const value = { tenantId, tenantName: access.tenant.get('tradeName') ?? tenantId, authorUid: uid, authorName: access.member.get('name') ?? 'Gestor',
      subject, message, status: 'OPEN', replies: [], createdAt: now, createdAtMs: Date.parse(now), updatedAt: now };
    tx.create(ref, value);
    // The receipt keeps this result: identifiers only, never the message.
    return { supportRequestId: ref.id, status: 'OPEN' };
  }, ['MANAGER'], undefined, { pausedPrincipal: true });
});

export const addSupportMessage = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'requestId', 'supportRequestId', 'message'], 'Mensagem de suporte');
  const supportRequestId = identifier(request.data.supportRequestId, 'Pedido de suporte'); const message = text(request.data.message, 'Mensagem', 2000, 3);
  return teamCommand(request, 'addSupportMessage', { supportRequestId, message }, async ({ db, tx, tenantId, uid, access }) => {
    const ref = requestRef(db, supportRequestId); const previous = await tx.get(ref);
    if (!previous.exists || previous.get('tenantId') !== tenantId) throw new HttpsError('not-found', 'Pedido de suporte não encontrado.');
    if (previous.get('status') === 'CLOSED') throw new HttpsError('failed-precondition', 'Este pedido foi encerrado. Abra um novo pedido.');
    const replies = previous.get('replies') ?? []; if (replies.length >= MAX_MESSAGES) invalid('Limite de mensagens deste pedido atingido.');
    const now = new Date().toISOString();
    const updated = [...replies, { from: 'TENANT', authorUid: uid, authorName: access.member.get('name') ?? 'Gestor', message, at: now }];
    tx.update(ref, { replies: updated, status: 'OPEN', updatedAt: now });
    return { supportRequestId, status: 'OPEN' };
  }, ['MANAGER'], undefined, { pausedPrincipal: true });
});

export const getSupportRequests = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId', 'cursor'], 'Consulta');
  const tenantId = identifier(request.data.tenantId, 'Empresa'); const cursor = cursorValue(request.data);
  return db.runTransaction(async (tx) => {
    await teamAccess(tx, db, tenantId, uid, ['MANAGER'], { pausedPrincipal: true });
    // updatedAt is an ISO-8601 UTC text, so its text order is its time order.
    return page(tx, db, db.collection('supportRequests').where('tenantId', '==', tenantId).orderBy('updatedAt', 'desc'), cursor, tenantId);
  });
});

export const getSaasSupportRequests = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  await requireEmailSession(request, db, uid);
  object(request.data, ['cursor'], 'Consulta');
  const cursor = cursorValue(request.data);
  return db.runTransaction(async (tx) => {
    await adminAccess(tx, db, uid);
    return page(tx, db, db.collection('supportRequests').orderBy('createdAtMs', 'desc'), cursor);
  });
});

export const replySupportRequest = onCall(options, async (request) => {
  object(request.data, ['requestId', 'supportRequestId', 'message', 'close'], 'Resposta de suporte');
  const supportRequestId = identifier(request.data.supportRequestId, 'Pedido de suporte'); const message = text(request.data.message, 'Resposta', 2000, 3);
  if (typeof request.data.close !== 'boolean') invalid('Informe se o pedido será encerrado.');
  const close = request.data.close;
  return platformCommand(request, 'replySupportRequest', { supportRequestId, message, close }, async ({ tx, db, uid }) => {
    const ref = requestRef(db, supportRequestId); const previous = await tx.get(ref);
    if (!previous.exists) throw new HttpsError('not-found', 'Pedido de suporte não encontrado.');
    if (previous.get('status') === 'CLOSED') throw new HttpsError('failed-precondition', 'Este pedido já foi encerrado.');
    const replies = previous.get('replies') ?? []; if (replies.length >= MAX_MESSAGES) invalid('Limite de mensagens deste pedido atingido.');
    const now = new Date().toISOString(); const status = close ? 'CLOSED' : 'ANSWERED';
    tx.update(ref, { replies: [...replies, { from: 'PLATFORM', authorUid: uid, authorName: 'Suporte Cãopanheiro', message, at: now }], status, updatedAt: now });
    notify(tx, db, previous.get('tenantId'), uid, [{ role: 'TEAM', targetUid: previous.get('authorUid'), type: 'SUPPORT_REPLY',
      title: close ? 'Pedido de suporte encerrado' : 'Suporte respondeu ao seu pedido', text: previous.get('subject'), supportRequestId }]);
    return { supportRequestId, tenantId: previous.get('tenantId'), status };
  });
});
