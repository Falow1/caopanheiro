import { HttpsError } from 'firebase-functions/v2/https';
export function requirePrincipal(member) {
  if (member?.active !== true || !member.roles?.includes('MANAGER') || member.managementDelegated === true)
    throw new HttpsError('permission-denied', 'Somente o gestor principal pode administrar os vínculos da equipe.');
}
export function publicProfessional(doc) {
  const value = doc.data();
  return {id:doc.id, recordNumber:value.recordNumber ?? null, name:value.name ?? 'Profissional', specialty:value.specialty ?? '', active:value.active === true,
    ...(value.availability == null ? {} : {availability:value.availability}), linked:value.authUid != null, createdAt:null, updatedAt:null};
}
