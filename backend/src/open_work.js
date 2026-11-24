// Open situations are the exact complement of the closed ones:
// appointments close as COMPLETED, CANCELLED or NO_SHOW; transports as
// DELIVERED or CANCELLED; transport requests as CONFIRMED, REJECTED or
// CANCELLED. Asking only for open records keeps a long history from
// blocking an unlink, a role change, a transfer or an account deletion.
export const openAppointmentStatuses = ['REQUESTED', 'CONFIRMED', 'PET_RECEIVED', 'IN_PROGRESS'];
export const openTransportStatuses = ['ASSIGNED', 'GOING_TO_ORIGIN', 'PET_COLLECTED', 'IN_TRANSIT'];
export const openTransportRequestStatuses = ['REQUESTED'];

const openStatuses = {
  appointments: openAppointmentStatuses,
  transports: openTransportStatuses,
  transportRequests: openTransportRequestStatuses,
};

/// True when at least one record of the collection matching field == value
/// is still open. Reads at most one document.
export async function hasOpenWork(tx, db, tenantId, collection, field, value) {
  const statuses = openStatuses[collection];
  if (!statuses) throw new Error('Coleção sem situações abertas conhecidas.');
  const page = await tx.get(db.collection(`tenants/${tenantId}/${collection}`)
    .where(field, '==', value).where('status', 'in', statuses).limit(1));
  return !page.empty;
}
