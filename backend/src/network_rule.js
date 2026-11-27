import { HttpsError } from 'firebase-functions/v2/https';

/// One principal manager per network and per petshop. A network is the set of
/// petshops of one principal manager: whoever leads a network does not take a
/// delegated management in another network, and a delegated manager of
/// another network does not take over a network of their own. Operational
/// roles (attendant, professional, driver) stay free across networks.
export async function managementLinks(tx, db, uid) {
  const links = await tx.get(db.collection(`users/${uid}/tenantLinks`).limit(51));
  if (links.size > 50) throw new HttpsError('failed-precondition', 'Quantidade de vínculos requer revisão administrativa.');
  const refs = links.docs.map((link) => db.doc(`tenants/${link.id}/members/${uid}`));
  const members = (refs.length ? await tx.getAll(...refs) : [])
    .filter((doc) => doc.exists && doc.get('active') === true && (doc.get('roles') ?? []).includes('MANAGER'));
  return {
    principalOf: members.filter((doc) => doc.get('managementDelegated') !== true).map((doc) => doc.ref.parent.parent.id),
    delegatedIn: members.filter((doc) => doc.get('managementDelegated') === true).map((doc) => doc.ref.parent.parent.id),
  };
}

/// Delegated management offered by [principalUid] in [tenantIds].
export async function requireDelegationAllowed(tx, db, uid, principalUid) {
  if (uid === principalUid) return;
  const { principalOf } = await managementLinks(tx, db, uid);
  if (principalOf.length) {
    throw new HttpsError('failed-precondition', 'Você é gestor principal da sua rede e não pode ser gestor de um petshop de outra rede.');
  }
}

/// A network of their own for [uid], who must not manage another network.
export async function requirePrincipalAllowed(tx, db, uid, tenantId) {
  const { delegatedIn } = await managementLinks(tx, db, uid);
  if (delegatedIn.some((id) => id !== tenantId)) {
    throw new HttpsError('failed-precondition', 'Esta conta é gestora de um petshop de outra rede. Peça ao gestor principal dessa rede para retirar o acesso antes de assumir uma rede própria.');
  }
}
