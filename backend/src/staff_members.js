import { HttpsError } from 'firebase-functions/v2/https';
import { Filter } from 'firebase-admin/firestore';

// tenants/{id}/members also holds the tutors linked to customer records, so
// reading the whole collection makes every team operation grow with the
// number of customers. This query returns only what the team, plan and SaaS
// checks look at: a team role, a pending staff/management invitation, a
// legacy manager invitation (invitedRole) or an account deleted by the SaaS
// (deletedByPlatform), which the SaaS lists while its Auth removal is still
// pending. Tutors without a team role and without an invitation are left out.
export const STAFF_QUERY_LIMIT = 500;
const teamRoles = ['MANAGER', 'ATTENDANT', 'PROFESSIONAL', 'DRIVER'];

export function staffMembersFilter() {
  return Filter.or(
    ...teamRoles.map((role) => Filter.where('roles', 'array-contains', role)),
    Filter.where('staffInvitationPending', '==', true),
    Filter.where('activationPending', '==', true),
    Filter.where('invitedRole', '==', 'MANAGER'),
    Filter.where('deletedByPlatform', '==', true),
  );
}

export function staffMembersQuery(db, tenantId) {
  return db.collection(`tenants/${tenantId}/members`).where(staffMembersFilter()).limit(STAFF_QUERY_LIMIT + 1);
}

/// Team members of a petshop, read inside a transaction (tx) or directly
/// (reader === db). More than STAFF_QUERY_LIMIT is refused unless the caller
/// only reports the usage and accepts a capped result.
export async function staffMembers(reader, db, tenantId, { allowCapped = false } = {}) {
  const query = staffMembersQuery(db, tenantId);
  const page = reader === db ? await query.get() : await reader.get(query);
  if (page.size > STAFF_QUERY_LIMIT && !allowCapped) {
    throw new HttpsError('failed-precondition', 'A equipe desta empresa passou de 500 pessoas e precisa de consulta ampliada. Fale com o suporte da plataforma.');
  }
  return page;
}
