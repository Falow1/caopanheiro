import { invitationValid, staffIssuedAt } from './invitation_policy.js';
import { operationalRoles } from './workforce_policy.js';
export function pendingStaff(member, now = Date.now()) {
  return member?.staffInvitationPending === true
    && invitationValid(member?.staffInvitationExpiresAt,staffIssuedAt(member),now)
    && Array.isArray(member.invitedRoles) && member.invitedRoles.length > 0
    && new Set(member.invitedRoles).size === member.invitedRoles.length
    && (member.linkInvitation === true && member.invitationKind === 'MANAGEMENT'
      ? member.invitedRoles.length === 1 && member.invitedRoles[0] === 'MANAGER'
      : member.invitedRoles.every(role => operationalRoles.includes(role)));
}
