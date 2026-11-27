// v63: Team login, invitation email lookup and persisted request limits.
// v62: booking quotes, pet reservations, custody and professional binding are validated by their modules.
import { effectiveManagementPermissions, requireManagementAction } from './management_permissions.js';
import { workforceRoles } from './workforce_policy.js';
import { allocateRecordNumbers, petNumberId } from './record_numbers.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { FieldValue } from 'firebase-admin/firestore';
import { options, digest, invalid, object, identifier, localBackend, actor, tenantEnabled, tenantOpen } from './runtime.js';
import { screenTips } from './screen_tips.js';
import { ACCESS_PAUSED, AWAITING_PAID_PLAN, BILLING_BLOCKED, companySuspended, principalMember, tenantFeature } from './access_policy.js';
import { phaseView, tenantPhase } from './billing_phase.js';
import { purgeAt, retention } from './retention.js';

const fields = ['name', 'description', 'priceCents', 'durationMinutes', 'active'];

function serviceFields(value, creating) {
  object(value, fields, 'Serviço');
  if (!Object.keys(value).length) invalid('Informe ao menos um campo.');
  const result = {};
  for (const key of fields) {
    if (!Object.hasOwn(value, key)) continue;
    const input = value[key];
    if (key === 'name' || key === 'description') {
      if (typeof input !== 'string') invalid(`${key} deve ser texto.`);
      const text = input.trim();
      if (text.length > (key === 'name' ? 100 : 1000) || (key === 'name' && text.length < 2)) {
        invalid(`${key} tem tamanho inválido.`);
      }
      result[key] = text;
    } else if (key === 'active') {
      if (typeof input !== 'boolean') invalid('active deve ser booleano.');
      result[key] = input;
    } else {
      if (!Number.isSafeInteger(input) || input < (key === 'priceCents' ? 0 : 1)) {
        invalid(`${key} deve ser inteiro válido ${key === 'priceCents' ? 'não negativo' : 'positivo'}.`);
      }
      result[key] = input;
    }
  }
  if (creating) {
    for (const key of ['name', 'priceCents', 'durationMinutes']) {
      if (!Object.hasOwn(result, key)) invalid(`${key} é obrigatório.`);
    }
    result.description ??= '';
    result.active ??= true;
  }
  return result;
}

function jsonService(value, id) {
  return { id, ...value, createdAt: value.createdAt.toDate().toISOString(),
    updatedAt: value.updatedAt.toDate().toISOString() };
}

async function command(request, action) {
  const db = localBackend();
  const uid = await actor(request);
  const creating = action === 'create';
  const allowed = ['tenantId', 'requestId', ...(creating ? ['service'] : ['serviceId']),
    ...(action === 'update' ? ['changes'] : [])];
  object(request.data, allowed, 'Pedido');
  const tenantId = identifier(request.data.tenantId, 'Empresa');
  const requestId = identifier(request.data.requestId, 'Identificador da operação', 16);
  const changes = action === 'deactivate' ? { active: false }
    : serviceFields(creating ? request.data.service : request.data.changes, creating);
  const receiptId = digest(JSON.stringify([uid, requestId]));
  const serviceId = creating ? digest(JSON.stringify([tenantId, uid, requestId]))
    : identifier(request.data.serviceId, 'Serviço');
  const inputHash = digest(JSON.stringify([action, serviceId, changes]));
  const tenantRef = db.doc(`tenants/${tenantId}`);
  const memberRef = tenantRef.collection('members').doc(uid);
  const serviceRef = tenantRef.collection('services').doc(serviceId);
  const receiptRef = tenantRef.collection('serviceCommandReceipts').doc(receiptId);
  const replayed = await db.runTransaction(async (transaction) => {
    const [tenant, member, receipt, existing, subscription] = await transaction.getAll(tenantRef, memberRef, receiptRef, serviceRef, db.doc(`subscriptions/${tenantId}`));
    if (!(await tenantOpen(transaction, db, tenant, subscription))
      || !member.exists || member.get('active') !== true
      || !Array.isArray(member.get('roles')) || !member.get('roles').includes('MANAGER')) {
      throw new HttpsError('permission-denied', 'Somente gerente com vínculo ativo nesta empresa pode gerenciar serviços.');
    }
    requireManagementAction(member.data(), action + 'Service');
    if (receipt.exists) {
      if (receipt.get('inputHash') !== inputHash) {
        throw new HttpsError('already-exists', 'Este identificador já foi usado em outra operação.');
      }
      return true;
    }
    if (creating && existing.exists) throw new HttpsError('already-exists', 'Serviço já cadastrado.');
    if (!creating && !existing.exists) throw new HttpsError('not-found', 'Serviço não encontrado.');
    const [recordNumber]=await allocateRecordNumbers(transaction,db,tenantId,[{type:'services',id:serviceId,recordNumber:existing.get('recordNumber')}]);
    const now = FieldValue.serverTimestamp();
    let value;
    if (creating) {
      value = { ...changes, recordNumber, schemaVersion: 1, version: 1, createdBy: uid, updatedBy: uid,
        createdAt: now, updatedAt: now };
      transaction.create(serviceRef, value);
    } else {
      const previous = existing.data();
      if (!Number.isSafeInteger(previous.version) || previous.version < 1
        || !previous.createdAt?.toDate || !previous.updatedAt?.toDate) {
        throw new HttpsError('failed-precondition', 'Serviço requer correção do esquema no servidor.');
      }
      const nextVersion = previous.version + 1;
      if (!Number.isSafeInteger(nextVersion)) throw new HttpsError('failed-precondition', 'Versão inválida.');
      const patch = { ...changes, recordNumber, version: nextVersion, updatedBy: uid, updatedAt: now };
      // The transaction retries using current values; no version is supplied by the client.
      value = { ...previous, ...patch };
      transaction.update(serviceRef, patch);
    }
    // Receipt and service commit together. No automatic resubmission or offline queue.
    transaction.create(receiptRef, { action, actorUid: uid, inputHash, serviceId,
      service: value, confirmedAt: now, purgeAt: purgeAt(retention.receipt) });
    return false;
  });
  const receipt = await receiptRef.get();
  return { tenantId, requestId, replayed, service: jsonService(receipt.get('service'), serviceId) };
}

export const createService = onCall(options, (request) => command(request, 'create'));
export const updateService = onCall(options, (request) => command(request, 'update'));
export const deactivateService = onCall(options, (request) => command(request, 'deactivate'));

export const getTeamContext = onCall(options, async (request) => {
  const db = localBackend();
  const uid = await actor(request);
  object(request.data, [], 'Pedido');
  // The directory discovers links; only canonical membership grants access.
  const links = await db.collection(`users/${uid}/tenantLinks`).limit(51).get();
  if (links.size > 50) throw new HttpsError('failed-precondition', 'Quantidade de vínculos requer revisão administrativa.');
  const companies = [], managementCompanies = [], pausedCompanies = []; let blocked = false;
  for (const link of links.docs) {
    const id = identifier(link.id, 'Empresa');
    const [tenant, member, subscription] = await db.getAll(db.doc(`tenants/${id}`), db.doc(`tenants/${id}/members/${uid}`), db.doc(`subscriptions/${id}`));
    const roles = member.get('roles');
    const enabled = tenantEnabled(tenant, subscription);
    const billing = enabled ? await tenantPhase(db, db, tenant, subscription) : null;
    const billingBlocked = billing?.phase === BILLING_BLOCKED;
    // Display-only directory: never grants operational access to blocked tenants.
    if (tenant.exists && member.exists && member.get('active') === true && Array.isArray(roles) && roles.includes('MANAGER')) {
      const tenantStatus = tenant.get('status') === 'TRIAL' ? 'ACTIVE' : tenant.get('status');
      const subscriptionStatus = subscription.get('status');
      const status = billingBlocked ? 'ACCESS_PAUSED' : tenantStatus === 'ACTIVE' && !enabled
        ? subscription.get('pendingReason') === AWAITING_PAID_PLAN ? 'AWAITING_PAID_PLAN' : subscription.exists && ['EXPIRED', 'CANCELLED', 'PENDING'].includes(subscriptionStatus) ? 'SUBSCRIPTION_' + subscriptionStatus : 'UNAVAILABLE'
        : ['ACTIVE', 'SUSPENDED', 'ONBOARDING'].includes(tenantStatus) ? tenantStatus : 'UNKNOWN';
      managementCompanies.push({ id, name: tenant.get('tradeName') ?? id, status });
    }
    if (!member.exists || member.get('active') !== true || !Array.isArray(roles)) continue;
    const owner = subscription.get('accountId') === uid;
    if (!enabled || billingBlocked) {
      const staff = tenant.exists && workforceRoles(roles).length > 0;
      blocked ||= staff;
      // Paused access (E2): only the principal manager still opens the petshop,
      // for the plan, Support and the export; nothing else is listed.
      const suspended = tenant.exists && companySuspended(tenant.data());
      if (staff && principalMember(member.data()) && (suspended || billingBlocked)) {
        pausedCompanies.push({ id, name: tenant.get('tradeName') ?? id, reason: suspended ? 'SUSPENDED' : 'BILLING', owner,
          ...(billingBlocked ? { billing: phaseView(billing, owner) } : {}) });
      }
      continue;
    }
    const availableRoles = workforceRoles(roles);
    const role = availableRoles[0] ?? null;
    const notice = phaseView(billing, owner);
    if (role) companies.push({ id, recordNumber: tenant.get('recordNumber') ?? null, name: tenant.get('tradeName') ?? id,
      userName: member.get('name') ?? 'Equipe', userPhone: member.get('phone') ?? '', role, roles: availableRoles, entitlements: { tutorApp: tenantFeature(subscription, 'tutorApp'), transport: tenantFeature(subscription, 'transport'), onlinePayment: tenantFeature(subscription, 'onlinePayment') }, managementDelegated: member.get('managementDelegated') === true, managementPermissions: effectiveManagementPermissions(member.data()),
      ...(notice ? { billing: notice } : {}) });
  }
  pausedCompanies.sort((a, b) => a.name.localeCompare(b.name, 'pt-BR'));
  managementCompanies.sort((a,b)=>a.name.localeCompare(b.name,'pt-BR'));
  if (!companies.length && pausedCompanies.length) return { uid, companies, pausedCompanies, managementCompanies, screenTips: screenTips(await db.doc('users/' + uid).get()) };
  if (!companies.length && blocked) throw new HttpsError('permission-denied', ACCESS_PAUSED, { reason: 'COMPANY_UNAVAILABLE' });
  if (!companies.length) throw new HttpsError('permission-denied', 'Sua conta não possui vínculo ativo. Se recebeu um convite de gestor, conclua Primeiro acesso.');
  companies.sort((a, b) => a.name.localeCompare(b.name, 'pt-BR'));
  return { uid, companies, pausedCompanies, managementCompanies, screenTips: screenTips(await db.doc('users/' + uid).get()) };
});

export { getTeamCustomers, saveCustomer, savePet, createTutorLink, acceptTutorLink } from './customers.js';
export { getPetPolicy, savePetPolicy, blockPet, unblockPet } from './pet_service.js';

export { getAvailableSlots, saveAppointment, updateAppointmentNotes, updateAppointmentStatus, getTeamResource, getSchedulingPolicy, saveSchedulingPolicy, saveProfessional, saveBlock, removeBlock } from './scheduling.js';

export { getApplicationContext, getProfileData, addServiceObservation, updateTutorProfile, updateOwnTeamProfile, saveTutorPet } from './profiles.js';
export { getCompanyDrivers, createTransport, transitionTransport, addTransportIncident } from './transports.js';

export { getSaasContext, getSaasData, saveTenant, setTenantStatus, savePlan, updateSubscription, saveTenantMember, setTenantUserActive, removeBreedSuggestion } from './saas.js';

export { getSaasDiagnostics } from './saas.js';
export { recordSaasSession, changeSaasPassword, getSaasHealth, live, ready } from './saas_security.js';

export { requestSaasEmailCode, verifySaasEmailCode } from './saas_email.js';
export { requestLoginCode, verifyLoginCode } from './login_code.js';
export { registerPushToken, unregisterPushToken } from './push_tokens.js';

export { getTransportConflicts, getCompanyTransports, reassignTransport, manageTransportIncident, checkTransportPets } from './transport_operations.js';

export {getTransportPolicy,saveTransportPolicy,searchTransportAddress,reverseTransportAddress,estimateTransportTrip,quoteTutorTransport,getTransportRequests,decideTransportRequest,getTutorTransportTracking,requestTutorTransport} from './transport_booking.js';
export { reportDriverLocation, getTransportLocation } from './driver_location.js';

export { getManagerActivation, completeManagerActivation } from './manager_activation.js';

export { inviteWorkforceUser, revokeWorkforceInvitation, getStaffActivation, completeStaffActivation } from './staff_invitations.js';
export { getWorkforceMembers, saveWorkforceRoles, unlinkWorkforceMember } from './workforce.js';

export {inspectTeamLogin,loginTeam,requestTeamLoginEmail} from './team_login.js';

export { createStaffLink, inspectStaffLink, loginStaffLink, acceptStaffLink } from './staff_links.js';

export { unlinkCustomerAccount } from './customer_unlink.js';

export { getTutorJoinLink, setTutorJoinLink, decideTutorReturn } from './tutor_join_link.js';

export { deleteOwnAccount, deleteManagerAccount } from './account_deletion.js';

export { getCompanyView } from './company_view.js';

export { saveTutorAccountProfile, saveTutorAddress } from './tutor_account_profile.js';

export { getNotices, markNoticesSeen } from './notices.js';

export { getCompanyPlan } from './company_plan.js';

export { getBillingOverview, requestPlanChange, cancelSubscription, changeAccountTenant, requestRenewal, renewSubscriptionUntil, getBillingRequests, decideBillingRequest, runBillingRoutine } from './billing.js';

export { exportTenantData } from './tenant_export.js';

export { updateScreenTips } from './screen_tips.js';

export { createSupportRequest, addSupportMessage, getSupportRequests, getSaasSupportRequests, replySupportRequest } from './support.js';

export { signalTenantRecord, signalTenant, signalSubscription, signalSupportRequest, signalPlan, signalPlatformAudit, signalBillingAccount, signalBillingRequest } from './live_signals.js';
