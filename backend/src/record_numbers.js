import { createHash } from 'node:crypto';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

export const tenantNumberTypes = ['customers', 'pets', 'services', 'professionals', 'appointments', 'transports', 'blocks', 'members'];
export const platformNumberTypes = ['tenants', 'plans', 'subscriptions'];
export const validRecordNumber = (value) => Number.isSafeInteger(value) && value > 0;

export function numberSequence(db, tenantId, type) {
  const allowed = tenantId == null ? platformNumberTypes : tenantNumberTypes;
  if (!allowed.includes(type) || tenantId != null && (!tenantId || tenantId.includes('/'))) {
    throw new Error('Escopo de numeração inválido.');
  }
  return db.doc(`${tenantId == null ? '' : `tenants/${tenantId}/`}recordSequences/${type}`);
}

// Call only after the business validation/reads and before any transaction write.
// Multiple requests for the same sequence are reserved together (e.g. pets).
// Private assignments survive deletion, so numbers are never reused.
export async function prepareRecordNumbers(tx, db, tenantId, records) {
  if (!records.length) return {numbers:[],write(){}};
  const entries = records.map(({ type, id, recordNumber }) => {
    if (typeof id !== 'string' || !id.length) throw new Error('Identidade de numeração inválida.');
    const sequence = numberSequence(db, tenantId, type);
    const key = createHash('sha256').update(id).digest('hex');
    return { type, id, previous: recordNumber, sequence, assignment: sequence.collection('records').doc(key) };
  });
  if (new Set(entries.map((e) => e.assignment.path)).size !== entries.length) throw new Error('Cadastro repetido na reserva.');
  const sequences = [...new Map(entries.map((e) => [e.sequence.path, e.sequence])).values()];
  const snapshots = await tx.getAll(...sequences, ...entries.map((e) => e.assignment));
  const states = new Map(sequences.map((ref, index) => {
    const value = snapshots[index];
    const last = value.exists ? value.get('last') : 0;
    if (!Number.isSafeInteger(last) || last < 0) throw new HttpsError('failed-precondition', 'Contador de cadastros precisa de revisão.');
    return [ref.path, { ref, last, changed: false }];
  }));
  const reservations = [];
  const numbers = entries.map((entry, index) => {
    const existing = snapshots[sequences.length + index];
    const state = states.get(entry.sequence.path);
    if (existing.exists) {
      const number = existing.get('number');
      if (existing.get('recordId') !== entry.id || !validRecordNumber(number) || number > state.last
        || entry.previous != null && entry.previous !== number) {
        throw new HttpsError('failed-precondition', 'Numeração do cadastro inconsistente.');
      }
      return number;
    }
    // Existing numbers without their registry must never be silently reassigned.
    if (entry.previous != null) throw new HttpsError('failed-precondition', 'Cadastro numerado sem registro de sequência. Revise a migração.');
    if (!Number.isSafeInteger(state.last + 1)) throw new HttpsError('resource-exhausted', 'Limite da sequência atingido.');
    const number = ++state.last; state.changed = true;
    reservations.push({ ref: entry.assignment, recordId: entry.id, number });
    return number;
  });
  return {numbers, write() {
  for (const state of states.values()) if (state.changed) tx.set(state.ref, { last: state.last, updatedAt: FieldValue.serverTimestamp() });
  for (const { ref, recordId, number } of reservations) tx.create(ref, { recordId, number, createdAt: FieldValue.serverTimestamp() });
  }};
}
export async function allocateRecordNumbers(tx,db,tenantId,records) {
  const prepared=await prepareRecordNumbers(tx,db,tenantId,records);
  prepared.write();return prepared.numbers;
}

export const petNumberId = (customerId, petId) => JSON.stringify([customerId, petId]);
