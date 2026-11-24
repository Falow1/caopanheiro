import { HttpsError } from 'firebase-functions/v2/https';
export const managementPermissions = ['CUSTOMERS','APPOINTMENTS','SERVICES','PROFESSIONALS','TRANSPORT','SETTINGS'];
export function parseManagementPermissions(value) {
  if (!Array.isArray(value) || !value.length || new Set(value).size !== value.length || value.some(p => !managementPermissions.includes(p)))
    throw new HttpsError('invalid-argument','Selecione ao menos uma permissão de gestão válida.');
  return managementPermissions.filter(p => value.includes(p));
}
export function effectiveManagementPermissions(member) {
  if (!member?.roles?.includes('MANAGER')) return [];
  // Legacy delegated managers already had full operational management.
  return member.managementDelegated !== true || member.managementPermissions == null
    ? [...managementPermissions] : managementPermissions.filter(p => Array.isArray(member.managementPermissions) && member.managementPermissions.includes(p));
}
const actions = {
  saveCustomer:'CUSTOMERS',savePet:'CUSTOMERS',createTutorLink:'CUSTOMERS',getTutorJoinLink:'CUSTOMERS',
  saveAppointment:'APPOINTMENTS',updateAppointmentNotes:'APPOINTMENTS',updateAppointmentStatus:'APPOINTMENTS',addServiceObservation:'APPOINTMENTS',saveBlock:'APPOINTMENTS',removeBlock:'APPOINTMENTS',
  createService:'SERVICES',updateService:'SERVICES',deactivateService:'SERVICES',
  saveProfessional:'PROFESSIONALS',saveSchedulingPolicy:'SETTINGS',saveTransportPolicy:'SETTINGS',
  createTransport:'TRANSPORT',transitionTransport:'TRANSPORT',addTransportIncident:'TRANSPORT',decideTransportRequest:'TRANSPORT',reassignTransport:'TRANSPORT',manageTransportIncident:'TRANSPORT',checkTransportPets:'TRANSPORT',
};
export function requireManagementAction(member, action) {
  const permission=actions[action];
  if (permission && member?.roles?.includes('MANAGER') && member.managementDelegated === true && !effectiveManagementPermissions(member).includes(permission))
    throw new HttpsError('permission-denied','Seu acesso não permite alterar esta área do petshop.');
}
