import { prepareTenantLinks } from './tenant_links.js';
import { requireManagementAction } from './management_permissions.js';
import { INVITATION_TTL_MS, invitationValid, tutorIssuedAt } from './invitation_policy.js';
import { allocateRecordNumbers, petNumberId } from './record_numbers.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { getAuth } from 'firebase-admin/auth';
import { FieldPath, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { randomBytes } from 'node:crypto';
import { actor, digest, email, identifier, invalid, localBackend, object, options, teamAccess, text, tenantEnabled, tenantOpen, accountAvailable } from './runtime.js';
import { brazilPhone } from './contact_policy.js';
import { metadata, teamCommand } from './team_commands.js';
import { joinTutorLink, requireTutorApp } from './tutor_join_link.js';
import { tenantFeature } from './access_policy.js';
import { purgeAt, retention } from './retention.js';
import { keepLegacyBreed, normalizedPet, petBlocksRef, petInput, petPolicyRef, petServiceContext, publicPetPolicy, refuseUnservedPet, servedCustomer, storedPetPolicy } from './pet_policy.js';
import { recordBreedSuggestion } from './pet_service.js';

const customerFields = ['name', 'phone', 'email'];
export const sortedPets = (pets) => Object.values(pets ?? {}).map(normalizedPet).sort((a, b) => a.name.localeCompare(b.name, 'pt-BR'));
export function jsonCustomer(snapshot) {
  const value = snapshot.data();
  return { id: snapshot.id, recordNumber: value.recordNumber ?? null, name: value.name, phone: value.phone, email: value.email,
    tutorUid: value.tutorUid ?? null, pets: sortedPets(value.pets) };
}
/// Team view of customers: each pet says whether the petshop serves it and,
/// when the team marked it, the block with its internal reason.
export async function teamCustomers(reader, db, tenantId, snapshots) {
  const context = await petServiceContext(reader, db, tenantId, snapshots.map((doc) => doc.id));
  return { customers: snapshots.map((doc) => servedCustomer(jsonCustomer(doc), context, { team: true })), petPolicy: publicPetPolicy(context.policy) };
}

export const getTeamCustomers = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId', 'cursor'], 'Consulta');
  const tenantId = identifier(request.data.tenantId, 'Empresa');
  const cursor = request.data.cursor == null ? null : identifier(request.data.cursor, 'Página');
  return db.runTransaction(async (tx) => {
    await teamAccess(tx, db, tenantId, uid);
    let query = db.collection(`tenants/${tenantId}/customers`).orderBy(FieldPath.documentId()).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await tx.get(query);
    const { customers, petPolicy } = await teamCustomers(tx, db, tenantId, page.docs);
    return { customers, petPolicy, nextCursor: page.size === 100 ? page.docs.at(-1).id : null };
  });
});

export const saveCustomer = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'requestId', 'customerId', 'customer'], 'Pedido');
  const customerId = identifier(request.data.customerId, 'Cliente');
  object(request.data.customer, customerFields, 'Cliente');
  const customer = { name: text(request.data.customer.name, 'Nome', 100, 2),
    phone: brazilPhone(text(request.data.customer.phone, 'Telefone', 32, 8)), email: email(request.data.customer.email) };
  return teamCommand(request, 'saveCustomer', { customerId, customer }, async ({ db, tx, tenantId, uid }) => {
    const ref = db.doc(`tenants/${tenantId}/customers/${customerId}`); const previous = await tx.get(ref);
    const [recordNumber] = await allocateRecordNumbers(tx, db, tenantId, [{type:'customers',id:customerId,recordNumber:previous.get('recordNumber')}]);
    const patch = { ...customer, recordNumber, ...metadata(uid, previous.exists) };
    if (previous.exists) tx.update(ref, patch);
    else tx.create(ref, { ...patch, pets: {}, tutorUid: null });
    // Customer edits never overwrite pets or assign a tutor UID.
    return { customer: { id: customerId, recordNumber, ...customer, tutorUid: previous.get('tutorUid') ?? null, pets: sortedPets(previous.get('pets')) } };
  });
});

export const savePet = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'requestId', 'customerId', 'petId', 'pet'], 'Pedido');
  const customerId = identifier(request.data.customerId, 'Cliente'); const petId = identifier(request.data.petId, 'Pet');
  const { pet: input, suggestion } = petInput(request.data.pet, petId);
  return teamCommand(request, 'savePet', { customerId, pet: input, suggestion }, async ({ db, tx, tenantId, uid }) => {
    const ref = db.doc(`tenants/${tenantId}/customers/${customerId}`);
    const [previous, policyDoc, blocks] = await tx.getAll(ref, petPolicyRef(db, tenantId), petBlocksRef(db, tenantId, customerId));
    if (!previous.exists) throw new HttpsError('not-found', 'Cliente não encontrado.');
    const pets = previous.get('pets') ?? {};
    if (!pets[petId] && Object.keys(pets).length >= 100) invalid('Limite de pets deste cadastro atingido.');
    // After linking, the tutor manages the pets in this customer record.
    if (previous.get('tutorUid')) throw new HttpsError('failed-precondition', 'Os dados deste pet são mantidos pelo tutor no app.');
    const before = pets[petId] ? normalizedPet(pets[petId]) : null;
    const pet = keepLegacyBreed({ ...input, notes: before?.notes ?? '' }, before); const policy = storedPetPolicy(policyDoc);
    // A new pet or a new breed follows the rule of the petshop; the other
    // data of a pet it no longer serves can still be edited.
    if (!before || before.breedCode !== pet.breedCode) refuseUnservedPet(policy, pet);
    [pet.recordNumber] = await allocateRecordNumbers(tx, db, tenantId, [{type:'pets',id:petNumberId(customerId,petId),recordNumber:pets[petId]?.recordNumber}]);
    tx.update(ref, { [`pets.${petId}`]: pet, ...metadata(uid, true) });
    if (suggestion) recordBreedSuggestion(tx, db, pet.species, suggestion);
    const customer = { ...jsonCustomer(previous), pets: sortedPets({ ...pets, [petId]: pet }) };
    return { customer: servedCustomer(customer, { policy, blocks: new Map([[customerId, blocks.get('pets') ?? {}]]) }, { team: true }) };
  });
});

// Codes are given to the tutor by the operator; this function sends no messages.
export const createTutorLink = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId', 'customerId'], 'Pedido');
  const tenantId = identifier(request.data.tenantId, 'Empresa'); const customerId = identifier(request.data.customerId, 'Cliente');
  const token = randomBytes(32).toString('base64url'); const tokenHash = digest(token);
  const issuedAt=Timestamp.now(),expiresAt = Timestamp.fromMillis(issuedAt.toMillis() + INVITATION_TTL_MS);
  await db.runTransaction(async (tx) => {
    const access=await teamAccess(tx, db, tenantId, uid);
    requireManagementAction(access.member.data(),'createTutorLink');
    requireTutorApp(access.subscription);
    const ref = db.doc(`tenants/${tenantId}/customers/${customerId}`); const customer = await tx.get(ref);
    if (!customer.exists) throw new HttpsError('not-found', 'Cliente não encontrado.');
    if (customer.get('tutorUid')) throw new HttpsError('failed-precondition', 'Este cadastro já possui tutor vinculado.');
    const targetEmail = email(customer.get('email'));
    tx.update(ref, { inviteHash: tokenHash, ...metadata(uid, true) });
    tx.create(db.doc(`tenants/${tenantId}/tutorInvites/${tokenHash}`), { customerId, targetEmail, issuedAt, expiresAt, used: false, createdBy: uid, purgeAt: purgeAt(retention.afterExpiry, expiresAt.toMillis()) });
  });
  return { code: `${tenantId}.${customerId}.${token}`, expiresAt: expiresAt.toDate().toISOString() };
});

export const acceptTutorLink = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['code'], 'Pedido');
  const parts = text(request.data.code, 'Código', 400, 10).split('.');
  // Two parts: the petshop's fixed link. Three parts: the individual invite.
  if (parts.length === 2) return joinTutorLink(db, uid, parts);
  if (parts.length !== 3) invalid('Código inválido.');
  const tenantId = identifier(parts[0], 'Empresa'); const customerId = identifier(parts[1], 'Cliente');
  if (!/^[A-Za-z0-9_-]{43}$/.test(parts[2])) invalid('Código inválido.');
  const tokenHash = digest(parts[2]); const user = await getAuth().getUser(uid);
  if (!user.emailVerified || !user.email) throw new HttpsError('failed-precondition', 'Confirme o e-mail da sua conta antes de vincular.');
  await db.runTransaction(async (tx) => {
    await accountAvailable(tx,db,uid);
    const tenantRef = db.doc(`tenants/${tenantId}`); const customerRef = tenantRef.collection('customers').doc(customerId);
    const inviteRef = tenantRef.collection('tutorInvites').doc(tokenHash); const memberRef = tenantRef.collection('members').doc(uid);
    const returnRef = tenantRef.collection('tutorJoinRequests').doc(uid);
    const [tenant, customer, invite, member, subscription, returnRequest] = await tx.getAll(tenantRef, customerRef, inviteRef, memberRef, db.doc(`subscriptions/${tenantId}`), returnRef);
    if (!(await tenantOpen(tx, db, tenant, subscription)) || !customer.exists || !invite.exists
      || invite.get('customerId') !== customerId || invite.get('targetEmail') !== user.email.toLowerCase()
      || customer.get('email') !== user.email.toLowerCase() || customer.get('inviteHash') !== tokenHash
      || !invitationValid(invite.get('expiresAt'),tutorIssuedAt(invite.data()))) throw new HttpsError('permission-denied', 'Código inválido ou indisponível para esta conta.');
    if (!tenantFeature(subscription, 'tutorApp')) throw new HttpsError('permission-denied', 'Este petshop não está recebendo novos clientes pelo app no momento. Fale com o petshop.', { reason: 'TUTOR_APP_UNAVAILABLE' });
    if (invite.get('used') && customer.get('tutorUid') === uid) return;
    if (invite.get('used') || customer.get('tutorUid') || member.exists && (member.get('active') !== true && !member.get('tutorUnlinkedAt')
      || member.get('customerId') && member.get('customerId') !== customerId)) throw new HttpsError('permission-denied', 'Vínculo não permitido.');
    const writeLinks = await prepareTenantLinks(tx, db, uid, [tenantId]);
    const [recordNumber] = await allocateRecordNumbers(tx, db, tenantId, [{type:'members',id:uid,recordNumber:member.get('recordNumber')}]);
    writeLinks();
    // The petshop chose to bring the person back: the unlink mark and any
    // return request of the fixed link are cleared.
    tx.update(customerRef, { tutorUid: uid, tutorUnlinkedAt: FieldValue.delete(), ...metadata(uid, true) });
    if (returnRequest.exists) tx.delete(returnRef);
    tx.update(inviteRef, { used: true, usedBy: uid, usedAt: FieldValue.serverTimestamp() });
    tx.set(memberRef, { recordNumber, active: true, tutorUnlinkedAt: FieldValue.delete(), roles: FieldValue.arrayUnion('TUTOR'), customerId, name: user.displayName ?? customer.get('name') }, { merge: true });
    tx.set(db.doc(`users/${uid}/tenantLinks/${tenantId}`), { active: true, customerId }, { merge: true });
  });
  return { tenantId, customerId };
});
