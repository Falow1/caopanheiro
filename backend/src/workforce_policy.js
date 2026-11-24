import { effectiveManagementPermissions } from './management_permissions.js';
export const operationalRoles = ['ATTENDANT', 'PROFESSIONAL', 'DRIVER'];
export function workforceRoles(roles) {
  if (!Array.isArray(roles)) return [];
  return roles.includes('MANAGER') ? ['MANAGER', ...operationalRoles]
    : operationalRoles.filter(role => roles.includes(role));
}
export function hasWorkforceRole(roles, role) {
  return workforceRoles(roles).includes(role);
}

export function driverEligible(member) {
  if (member?.active !== true || !hasWorkforceRole(member.roles, 'DRIVER')) return false;
  return !member.roles.includes('MANAGER') || effectiveManagementPermissions(member).includes('TRANSPORT');
}
