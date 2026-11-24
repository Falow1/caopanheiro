import { driverEligible } from './workforce_policy.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { conflictPreview, conflictsFor, transportZone } from './transport_operations.js';

export async function appointmentTransportRows(tx, db, tenantId, appointmentId) {
  const root = `tenants/${tenantId}`;
  const requests = await tx.get(db.collection(`${root}/transportRequests`).where('appointmentId','==',appointmentId).limit(101));
  const jobs = await tx.get(db.collection(`${root}/transports`).where('appointmentId','==',appointmentId).limit(101));
  if (requests.size > 100 || jobs.size > 100) throw new HttpsError('failed-precondition','Quantidade de transportes requer revisão administrativa.');
  return {requests:requests.docs,jobs:jobs.docs};
}
export function rescheduledJob(job, startDelta, endDelta, zone) {
  const previous = Date.parse(job.scheduledAt);
  const next = previous + (job.type === 'RETURN' ? endDelta : startDelta);
  if (!Number.isFinite(next) || next <= Date.now()) throw new HttpsError('failed-precondition','A nova programação deixa um transporte no passado. Escolha outro horário.');
  return {...job,scheduledAt:new Date(next).toISOString(),timeZone:job.timeZone??zone};
}
export async function prepareTransportReschedule(tx, db, tenantId, uid, access, existing, appointmentId, booking, startsAt, endsAt) {
  const rows = await appointmentTransportRows(tx,db,tenantId,appointmentId);
  if (!existing.get('transport') && !rows.requests.length && !rows.jobs.length) return null;
  if (!access.member.get('roles').some(role=>['MANAGER','ATTENDANT'].includes(role))) throw new HttpsError('permission-denied','A remarcação com transporte é feita pela equipe.');
  const oldPets = (existing.get('items')??[]).map(item=>item.pet.id).sort();
  const newPets = booking.items.map(item=>item.pet.id).sort();
  if (JSON.stringify(oldPets)!==JSON.stringify(newPets)) throw new HttpsError('failed-precondition','Não troque os pets de uma reserva com transporte. Revise os transportes com a equipe.');
  if (rows.jobs.some(doc=>!['ASSIGNED','CANCELLED'].includes(doc.get('status')))) throw new HttpsError('failed-precondition','Transporte já iniciado ou concluído. Resolva a viagem antes de remarcar; observações podem ser editadas separadamente.');
  const moved = rows.jobs.filter(doc=>doc.get('status')==='ASSIGNED').map(doc=>({doc,value:rescheduledJob({id:doc.id,...doc.data()},Date.parse(startsAt)-existing.get('startsAt').toMillis(),Date.parse(endsAt)-existing.get('endsAt').toMillis(),transportZone(existing.data()))}));
  const ids = new Set(moved.map(row=>row.doc.id));
  for (const row of moved) {
    if (row.value.type==='PICKUP' && Date.parse(row.value.scheduledAt)>=Date.parse(startsAt) || row.value.type==='RETURN' && Date.parse(row.value.scheduledAt)<Date.parse(endsAt)) throw new HttpsError('failed-precondition','Horário do transporte incompatível com o novo atendimento.');
    if ((row.value.scheduleHistory??[]).length>=100) throw new HttpsError('failed-precondition','Limite de remarcações do transporte atingido.');
    const driver = await tx.get(db.doc(`tenants/${tenantId}/members/${row.value.driverUid}`));
    if (!driver.exists || !driverEligible(driver.data())) throw new HttpsError('failed-precondition','Revise o entregador dos transportes antes de remarcar.');
    const preview = await conflictPreview(tx,db,tenantId,row.value.driverUid,row.value.scheduledAt,row.value.estimatedDurationMinutes??null,row.doc.id);
    const external = preview.conflicts.filter(conflict=>!ids.has(conflict.id));
    const internal = conflictsFor(moved.map(item=>item.value),row.value.driverUid,row.value.scheduledAt,row.value.estimatedDurationMinutes??null,row.doc.id);
    if (external.length || internal.length) throw new HttpsError('failed-precondition','A remarcação conflita com a agenda do entregador. Escolha outro horário ou reatribua o transporte.');
  }
  return {reschedule:true,summary:existing.get('transport')??null,requests:rows.requests,moved,startsAt,uid};
}
