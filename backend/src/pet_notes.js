import { FieldPath } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { requireManagementAction } from './management_permissions.js';
import { actor, identifier, localBackend, object, options, teamAccess, text } from './runtime.js';
import { teamCommand } from './team_commands.js';

const PAGE_SIZE = 50;

async function noteCollection(tx, db, tenantId, customerId, petId) {
  const customer = db.doc(`tenants/${tenantId}/customers/${customerId}`);
  const current = await tx.get(customer);
  if (!current.exists || !Object.hasOwn(current.get('pets') ?? {}, petId)) {
    throw new HttpsError('not-found', 'Pet não encontrado.');
  }
  return customer.collection('petInternalNotes').doc(petId).collection('entries');
}

export const getPetInternalNotes = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  object(request.data, ['tenantId', 'customerId', 'petId', 'cursor'], 'Consulta');
  const tenantId = identifier(request.data.tenantId, 'Empresa');
  const customerId = identifier(request.data.customerId, 'Cliente');
  const petId = identifier(request.data.petId, 'Pet');
  const cursor = request.data.cursor == null ? null : identifier(request.data.cursor, 'Página');
  return db.runTransaction(async (tx) => {
    const access = await teamAccess(tx, db, tenantId, uid);
    requireManagementAction(access.member.data(), 'getPetInternalNotes');
    const entries = await noteCollection(tx, db, tenantId, customerId, petId);
    let query = entries.orderBy('createdAt', 'desc').orderBy(FieldPath.documentId(), 'desc').limit(PAGE_SIZE + 1);
    if (cursor) {
      const previous = await tx.get(entries.doc(cursor));
      if (!previous.exists) throw new HttpsError('invalid-argument', 'Página de observações inválida.');
      query = query.startAfter(previous);
    }
    const page = await tx.get(query);
    const rows = page.docs.slice(0, PAGE_SIZE);
    return {
      items: rows.map((doc) => ({ id: doc.id, text: doc.get('text'), createdAt: doc.get('createdAt'), authorName: doc.get('authorName') })),
      nextCursor: page.size > PAGE_SIZE ? rows.at(-1).id : null,
    };
  });
});

export const addPetInternalNote = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'requestId', 'customerId', 'petId', 'text'], 'Observação');
  const customerId = identifier(request.data.customerId, 'Cliente');
  const petId = identifier(request.data.petId, 'Pet');
  const value = text(request.data.text, 'Observação', 2000, 1);
  return teamCommand(request, 'addPetInternalNote', { customerId, petId, text: value }, async ({ db, tx, tenantId, uid, access }) => {
    const entries = await noteCollection(tx, db, tenantId, customerId, petId);
    const ref = entries.doc();
    const note = { text: value, createdAt: new Date().toISOString(), authorName: access.member.get('name') ?? '' };
    tx.create(ref, { ...note, authorUid: uid });
    return { note: { id: ref.id, ...note } };
  });
});
