import { HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { onCall } from './callable.js';
import { actor, digest, identifier, localBackend, object, options, teamAccess, text } from './runtime.js';
import { metadata, teamCommand } from './team_commands.js';
import { normalizeBreedText } from './pet_breeds.js';
import { petBlocksRef, petPolicyRef, petPolicyValue, publicPetPolicy, storedPetPolicy } from './pet_policy.js';

/// Pets the petshop serves: read by the team and by the tutor (who sees the
/// same rule in the pet form), changed by the manager (SETTINGS when delegated).
export const getPetPolicy = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId'], 'Consulta');
  const tenantId = identifier(request.data.tenantId, 'Empresa');
  return db.runTransaction(async (tx) => {
    await teamAccess(tx, db, tenantId, uid, ['MANAGER', 'ATTENDANT', 'TUTOR'], { tutorRead: true });
    return { policy: publicPetPolicy(storedPetPolicy(await tx.get(petPolicyRef(db, tenantId)))) };
  });
});

export const savePetPolicy = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'requestId', 'policy'], 'Pedido');
  const policy = petPolicyValue(request.data.policy);
  return teamCommand(request, 'savePetPolicy', policy, async ({ db, tx, tenantId, uid }) => {
    const ref = petPolicyRef(db, tenantId); const old = await tx.get(ref);
    const value = { ...policy, version: (old.get('version') ?? 0) + 1 };
    tx.set(ref, { ...value, ...metadata(uid, old.exists) });
    return { policy: value };
  }, ['MANAGER']);
});

const openStatuses = ['REQUESTED', 'CONFIRMED'];
/// Appointments of the pet still to happen. They stay booked: the block only
/// stops new appointments, reschedules and the pet being added to one.
async function futureAppointments(tx, db, tenantId, customerId, petId) {
  const page = await tx.get(db.collection(`tenants/${tenantId}/appointments`).where('customerId', '==', customerId)
    .where('status', 'in', openStatuses).limit(200));
  const now = Date.now();
  return page.docs.filter((doc) => (doc.get('startsAt')?.toMillis?.() ?? 0) > now
    && (doc.get('items') ?? []).some((item) => item?.pet?.id === petId)).length;
}

async function blockTarget(tx, db, tenantId, customerId, petId) {
  const [customer, blocks] = await tx.getAll(db.doc(`tenants/${tenantId}/customers/${customerId}`), petBlocksRef(db, tenantId, customerId));
  if (!customer.exists || !customer.get('pets')?.[petId]) throw new HttpsError('not-found', 'Pet não encontrado.');
  return blocks;
}

/// "Não atender este pet": only the team reads the reason.
export const blockPet = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'requestId', 'customerId', 'petId', 'reason'], 'Pedido');
  const customerId = identifier(request.data.customerId, 'Cliente'); const petId = identifier(request.data.petId, 'Pet');
  const reason = text(request.data.reason, 'Motivo', 300, 3);
  return teamCommand(request, 'blockPet', { customerId, petId, reason }, async ({ db, tx, tenantId, uid, access }) => {
    const blocks = await blockTarget(tx, db, tenantId, customerId, petId);
    const count = await futureAppointments(tx, db, tenantId, customerId, petId);
    const previous = blocks.get('pets')?.[petId];
    const block = { reason, createdBy: previous?.createdBy ?? uid, createdByName: previous?.createdByName ?? access.member.get('name') ?? null,
      createdAt: previous?.createdAt ?? new Date().toISOString(), ...(previous ? { updatedBy: uid } : {}) };
    tx.set(petBlocksRef(db, tenantId, customerId), { customerId, pets: { [petId]: block }, ...metadata(uid, blocks.exists) }, { merge: true });
    return { customerId, petId, block: { reason, createdAt: block.createdAt, createdByName: block.createdByName }, futureAppointments: count };
  }, ['MANAGER', 'ATTENDANT']);
});

export const unblockPet = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'requestId', 'customerId', 'petId'], 'Pedido');
  const customerId = identifier(request.data.customerId, 'Cliente'); const petId = identifier(request.data.petId, 'Pet');
  return teamCommand(request, 'unblockPet', { customerId, petId }, async ({ db, tx, tenantId, uid }) => {
    const blocks = await blockTarget(tx, db, tenantId, customerId, petId);
    const pets = { ...(blocks.get('pets') ?? {}) };
    if (pets[petId]) {
      delete pets[petId];
      const ref = petBlocksRef(db, tenantId, customerId);
      if (Object.keys(pets).length) tx.update(ref, { [`pets.${petId}`]: FieldValue.delete(), ...metadata(uid, true) });
      else tx.delete(ref);
    }
    return { customerId, petId, unblocked: true };
  }, ['MANAGER', 'ATTENDANT']);
});

/// A breed someone did not find on the list, for the platform to evaluate.
/// Only the name and the species are kept: no petshop, person or pet.
export function recordBreedSuggestion(tx, db, species, name) {
  const key = normalizeBreedText(name);
  if (key.length < 2) return;
  const ref = db.doc(`breedSuggestions/${digest(`${species}:${key}`)}`);
  tx.set(ref, { name, species, key, count: FieldValue.increment(1), lastAt: FieldValue.serverTimestamp() }, { merge: true });
}
