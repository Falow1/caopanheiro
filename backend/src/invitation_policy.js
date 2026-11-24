// Business invitations share a maximum lifetime. Native Auth action links have
// their own lifetime and never extend this authorization.
export const INVITATION_TTL_MS = 24 * 60 * 60 * 1000;
function millis(value) {
  try {const result=value?.toMillis?.();return Number.isFinite(result)?result:null;}
  catch {return null;}
}
export function invitationDeadline(expiresAt, issuedAt) {
  const expires=millis(expiresAt),issued=millis(issuedAt);
  return expires==null || issued==null || expires<=issued ? null : Math.min(expires,issued+INVITATION_TTL_MS);
}
export function invitationValid(expiresAt, issuedAt, now=Date.now()) {
  const issued=millis(issuedAt),deadline=invitationDeadline(expiresAt,issuedAt);
  return Number.isFinite(now)&&issued!=null&&issued<=now&&deadline!=null&&deadline>now;
}
export const managerIssuedAt=member=>member?.activationIssuedAt??member?.updatedAt??member?.createdAt;
export const staffIssuedAt=member=>member?.staffInvitationIssuedAt??member?.staffInvitationSentAt??member?.updatedAt??member?.createdAt;
// Tutor codes have always been issued for 24 hours. This derives the original
// issue time for that known legacy format, without extending the stored expiry.
export function tutorIssuedAt(invite) {
  if(invite?.issuedAt??invite?.createdAt)return invite.issuedAt??invite.createdAt;
  const expires=millis(invite?.expiresAt);
  return expires==null?null:{toMillis:()=>expires-INVITATION_TTL_MS};
}
