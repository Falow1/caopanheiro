import { requireManagementAction } from './management_permissions.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { actor, canonical, digest, identifier, localBackend, teamAccess } from './runtime.js';
import { purgeAt, retention } from './retention.js';

/// All callbacks finish their reads before writing. Authorization is repeated
/// inside the transaction, including when replaying a confirmed operation.
/// [accessOptions] go to teamAccess (pausedPrincipal for Support during a pause, E2).
export async function teamCommand(request, action, normalized, apply, roles, authorizeReplay, accessOptions = {}) {
  const db = localBackend();
  const uid = await actor(request);
  const tenantId = identifier(request.data.tenantId, 'Empresa');
  const requestId = identifier(request.data.requestId, 'Operação', 16);
  const hash = digest(JSON.stringify(canonical([action, normalized])));
  const receiptRef = db.doc(`tenants/${tenantId}/entityCommandReceipts/${digest(JSON.stringify([uid, requestId]))}`);
  const result = await db.runTransaction(async (tx) => {
    const access = await teamAccess(tx, db, tenantId, uid, roles, accessOptions);
    requireManagementAction(access.member.data(), action);
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.get('inputHash') !== hash) throw new HttpsError('already-exists', 'Operação já utilizada com outros dados.');
      if (authorizeReplay) await authorizeReplay({ db, tx, tenantId, uid, access });
      return { ...receipt.get('result'), replayed: true };
    }
    const value = await apply({ db, tx, tenantId, uid, access });
    tx.create(receiptRef, { action, inputHash: hash, actorUid: uid, result: value, confirmedAt: FieldValue.serverTimestamp(), purgeAt: purgeAt(retention.receipt) });
    return { ...value, replayed: false };
  });
  return { tenantId, requestId, ...result };
}

export function metadata(uid, exists) {
  const now = FieldValue.serverTimestamp();
  return { updatedBy: uid, updatedAt: now, schemaVersion: 1,
    ...(!exists ? { createdBy: uid, createdAt: now } : {}) };
}
