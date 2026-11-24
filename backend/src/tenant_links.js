import { HttpsError } from 'firebase-functions/v2/https';

// Call during the read phase; invoke the returned writer only after all reads.
// The shared profile revision serializes joins into different companies.
export async function prepareTenantLinks(tx, db, uid, additions, removals = []) {
  const profileRef = db.doc('users/' + uid);
  const profile = await tx.get(profileRef);
  if (profile.get('deletionState')) {
    throw new HttpsError('permission-denied', 'Esta conta está em exclusão.');
  }
  const links = await tx.get(profileRef.collection('tenantLinks').limit(51));
  const next = new Set(links.docs.map(doc => doc.id));
  for (const id of removals) next.delete(id);
  for (const id of additions) next.add(id);
  if (links.size > 50 || next.size > 50) {
    throw new HttpsError('failed-precondition', 'Limite de 50 vínculos da conta atingido.');
  }
  const revision = profile.get('tenantLinksRevision') ?? 0;
  if (!Number.isSafeInteger(revision) || revision < 0 || revision >= Number.MAX_SAFE_INTEGER) {
    throw new HttpsError('failed-precondition', 'O diretório de vínculos precisa de revisão.');
  }
  return () => tx.set(profileRef, {tenantLinksRevision: revision + 1}, {merge: true});
}
