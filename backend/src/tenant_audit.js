import { FieldValue } from 'firebase-admin/firestore';

// Sensitive actions performed inside a petshop are mirrored to the platform
// audit trail. Only identifiers and role names are stored: no contact data,
// customer names or free text written by the team.
export const tenantAuditActions = {
  UNLINKED: 'Petshop: integrante desvinculado',
  ROLES_CHANGED: 'Petshop: funções alteradas',
  MANAGEMENT_PERMISSIONS_CHANGED: 'Petshop: permissões de gestão alteradas',
  TRANSFERRED: 'Petshop: integrante transferido',
  TUTOR_UNLINKED: 'Petshop: conta de tutor desvinculada',
  ACCOUNT_DELETED: 'Petshop: conta excluída pelo titular',
  TUTOR_LINK_DISABLED: 'Petshop: link de convite desativado',
  TUTOR_LINK_ENABLED: 'Petshop: link de convite reativado',
  TUTOR_LINK_ROTATED: 'Petshop: link de convite trocado',
  TUTOR_RETURN_APPROVED: 'Petshop: retorno de tutor aprovado',
  TUTOR_RETURN_REFUSED: 'Petshop: retorno de tutor recusado',
  DATA_EXPORTED: 'Petshop: dados exportados pelo gestor principal',
};

/// Write-phase helper: call only after the transaction finished its reads
/// (or on a write batch).
export function tenantAudit(tx, db, tenantId, event, actorUid, actorName, details = {}) {
  const action = tenantAuditActions[event];
  if (!action) throw new Error('Evento de auditoria desconhecido.');
  tx.create(db.collection('platformAudit').doc(), {
    action, source: 'TENANT', event, admin: actorName ?? 'Integrante do petshop', actorUid,
    entity: tenantId, tenantId, result: 'Confirmado', reason: null, details, createdAt: FieldValue.serverTimestamp(),
  });
}
