import { FieldPath } from 'firebase-admin/firestore';
import { allocateRecordNumbers, petNumberId, validRecordNumber } from './record_numbers.js';

// Administrative backfill: changes only additive number fields, never paths,
// Auth users, content, timestamps, permissions or existing relationships.
export async function numberExistingRecords(db, { tenantIds, platform = true, apply = false } = {}) {
  const totals = { inspected: 0, missing: 0, updated: 0 };
  async function collection(path, type, tenantId) {
    let cursor;
    while (true) {
      let query = db.collection(path).orderBy(FieldPath.documentId()).limit(100);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const candidate of page.docs) {
        totals.inspected++;
        const absent = !validRecordNumber(candidate.get('recordNumber'))
          || type === 'customers' && Object.values(candidate.get('pets') ?? {}).some((pet) => !validRecordNumber(pet.recordNumber));
        if (absent) totals.missing++;
        if (!apply) continue;
        const changed = await db.runTransaction(async (tx) => {
          const snapshot = await tx.get(candidate.ref);
          if (!snapshot.exists) return false;
          const value = snapshot.data();
          const pets = type === 'customers' ? Object.entries(value.pets ?? {}) : [];
          // Historical presentation snapshots retain names/prices; only add numbers.
          let customer, appointment;
          if (type === 'appointments' && typeof value.customerId === 'string') {
            customer = await tx.get(db.doc(`tenants/${tenantId}/customers/${value.customerId}`));
          }
          if (type === 'transports' && typeof value.appointmentId === 'string') {
            appointment = await tx.get(db.doc(`tenants/${tenantId}/appointments/${value.appointmentId}`));
          }
          const numbers = await allocateRecordNumbers(tx, db, tenantId, [
            { type, id: snapshot.id, recordNumber: value.recordNumber },
            ...pets.map(([key, pet]) => ({ type: 'pets', id: petNumberId(snapshot.id, key), recordNumber: pet.recordNumber })),
          ]);
          const patch = {};
          if (value.recordNumber !== numbers[0]) patch.recordNumber = numbers[0];
          if (pets.some(([, pet], index) => pet.recordNumber !== numbers[index + 1])) {
            patch.pets = Object.fromEntries(pets.map(([key, pet], index) => [key, { ...pet, recordNumber: numbers[index + 1] }]));
          }
          if (customer?.exists) {
            if (value.customer && value.customer.recordNumber !== customer.get('recordNumber')) {
              patch.customer = { ...value.customer, recordNumber: customer.get('recordNumber') ?? null };
            }
            const currentPets = customer.get('pets') ?? {};
            const items = value.items ?? [];
            const numbered = items.map((item) => {
              const number = currentPets[item.pet?.id]?.recordNumber;
              return validRecordNumber(number) ? { ...item, pet: { ...item.pet, recordNumber: number } } : item;
            });
            if (JSON.stringify(items) !== JSON.stringify(numbered)) patch.items = numbered;
          }
          if (appointment?.exists && validRecordNumber(appointment.get('recordNumber'))
            && value.appointmentNumber !== appointment.get('recordNumber')) patch.appointmentNumber = appointment.get('recordNumber');
          if (Object.keys(patch).length) tx.update(snapshot.ref, patch);
          return Object.keys(patch).length > 0;
        });
        if (changed) totals.updated++;
      }
      if (page.size < 100) break;
      cursor = page.docs.at(-1).id;
    }
  }
  if (platform) {
    for (const type of ['plans', 'tenants', 'subscriptions']) await collection(type, type, null);
  }
  const companies = tenantIds ?? (await db.collection('tenants').select().get()).docs.map((doc) => doc.id);
  for (const tenantId of companies) {
    if (!tenantId || tenantId.includes('/')) throw new Error('Empresa inválida na migração.');
    for (const type of ['members', 'services', 'professionals', 'customers', 'appointments', 'transports', 'blocks']) {
      await collection(`tenants/${tenantId}/${type}`, type, tenantId);
    }
  }
  return totals;
}
