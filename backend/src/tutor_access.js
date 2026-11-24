// The customer record is the anchor of what a tutor may see or change: the
// account must be the one linked to the record and the membership must point
// to the same record. Appointments created before the link belong to it too.
export async function tutorOwnsCustomer(tx, db, tenantId, uid, access, customerId) {
  if (typeof customerId !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/.test(customerId)
    || !access.member.get('roles')?.includes('TUTOR') || access.member.get('customerId') !== customerId) return false;
  const customer = await tx.get(db.doc(`tenants/${tenantId}/customers/${customerId}`));
  return customer.exists && customer.get('tutorUid') === uid;
}

/// UID of the tutor currently linked to a customer record, or null.
export async function customerTutorUid(tx, db, tenantId, customerId) {
  if (typeof customerId !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/.test(customerId)) return null;
  const customer = await tx.get(db.doc(`tenants/${tenantId}/customers/${customerId}`));
  return customer.exists ? customer.get('tutorUid') ?? null : null;
}
