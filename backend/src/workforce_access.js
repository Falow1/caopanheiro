import { HttpsError } from 'firebase-functions/v2/https';
import { hasOpenWork } from './open_work.js';

// Every petshop-level editor must preserve activation authority held by SaaS.
export function requireEditableWorkforceMember(member) {
  if (member?.activationPending || member?.staffInvitationPending) throw new HttpsError('failed-precondition', 'Conclua ou revogue o convite pendente antes de editar funções.');
  if (member?.roles?.includes('MANAGER') && member.active !== true) {
    throw new HttpsError('failed-precondition', 'A reativação de gestor é administrada pelo SaaS.');
  }
}
// Only open records are read, so a long closed history never blocks.
export async function requireNoOpenAssignments(tx, db, tenantId, {professionalUid, professionalId, driverUid}) {
  const queries = [];
  if (professionalUid) queries.push(['appointments', 'professionalUid', professionalUid]);
  if (professionalId) queries.push(['appointments', 'professionalId', professionalId]);
  if (driverUid) queries.push(['transports', 'driverUid', driverUid]);
  for (const [collection, field, value] of queries) {
    if (await hasOpenWork(tx, db, tenantId, collection, field, value)) {
      throw new HttpsError('failed-precondition', 'Existem tarefas abertas nesta função. Conclua ou reatribua antes de removê-la.');
    }
  }
}
