import { hasWorkforceRole } from './workforce_policy.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';
import { ACCESS_PAUSED, BILLING_BLOCKED, TUTOR_APP_CLOSED, companyReleased, companySuspended, principalMember, subscriptionValid, tutorReadOnly } from './access_policy.js';
import { tenantPhase } from './billing_phase.js';

export const options = { region: 'southamerica-east1', timeoutSeconds: 30, maxInstances: 5 };
export const digest = (value) => createHash('sha256').update(value).digest('hex');
export function invalid(message) { throw new HttpsError('invalid-argument', message); }
export function object(value, allowed, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)
    || Object.keys(value).some((key) => !allowed.includes(key))) invalid(`${label}: campos inválidos.`);
}
export function identifier(value, label, min = 1) {
  if (typeof value !== 'string' || value.length < min || value.length > 128
    || !/^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(value)) invalid(`${label} inválido.`);
  return value;
}
export function text(value, label, max = 100, min = 0) {
  if (typeof value !== 'string' || value.trim().length < min || value.trim().length > max) invalid(`${label} inválido.`);
  return value.trim();
}
export function email(value) {
  const result = text(value, 'E-mail', 254, 3).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(result)) invalid('E-mail inválido.');
  return result;
}
const LOCAL_PROJECT = 'demo-caopanheiro-local';
// Real Firebase projects this backend may run in, outside the emulators. Any
// other project is refused, and so is a real project with an emulator variable.
export const ALLOWED_PROJECTS = Object.freeze(['caopanheiro-staging-fly']);
const emulatorVariables = ['FUNCTIONS_EMULATOR', 'FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_EMULATOR_HUB'];

/// 'local' in the emulators of this repository (fixed project and ports),
/// 'cloud' in a project of ALLOWED_PROJECTS; anything else is refused.
export function backendEnvironment(env = process.env) {
  if (env.FUNCTIONS_EMULATOR === 'true') {
    if (env.GCLOUD_PROJECT === LOCAL_PROJECT
      && env.FIRESTORE_EMULATOR_HOST === '127.0.0.1:8080'
      && env.FIREBASE_AUTH_EMULATOR_HOST === '127.0.0.1:9099') return 'local';
  } else if (ALLOWED_PROJECTS.includes(env.GCLOUD_PROJECT) && !emulatorVariables.some((name) => env[name] !== undefined)) {
    return 'cloud';
  }
  throw new HttpsError('failed-precondition', 'Este backend executa somente nos emuladores locais ou em um projeto autorizado.');
}

/// Every callable and trigger starts here. The name is kept from the time the
/// backend ran only in the emulators; the check is backendEnvironment.
export function localBackend() {
  const environment = backendEnvironment();
  // Firestore triggers run beside an app the emulator creates itself; only
  // the default app is checked, so callables and triggers share one setup.
  if (!getApps().some((app) => app.name === '[DEFAULT]')) {
    if (environment === 'local') initializeApp({ projectId: LOCAL_PROJECT });
    else initializeApp();
  }
  return getFirestore();
}
export async function actor(request, {allowDeleting=false}={}) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Faça login para continuar.');
  const header = request.rawRequest.get('authorization') ?? '';
  if (!header.startsWith('Bearer ')) throw new HttpsError('unauthenticated', 'Sessão inválida.');
  try {
    const token = await getAuth().verifyIdToken(header.slice(7), true);
    if (token.uid !== request.auth.uid) throw new Error('Identidade divergente.');
    if (!allowDeleting) await accountAvailable(getFirestore(),getFirestore(),token.uid);
    return token.uid;
  } catch { throw new HttpsError('unauthenticated', 'Sessão inválida, desativada ou revogada.'); }
}
/// [pausedPrincipal]: the principal manager still passes while the access is
/// paused (platform suspension or expired plan, E2), for Support, the plan
/// and the export only.
export async function teamAccess(reader, db, tenantId, uid, roles = ['MANAGER', 'ATTENDANT'], { tutorRead = false, pausedPrincipal = false } = {}) {
  await accountAvailable(reader,db,uid);
  const refs = [db.doc(`tenants/${tenantId}`), db.doc(`tenants/${tenantId}/members/${uid}`), db.doc(`subscriptions/${tenantId}`)];
  const [tenant, member, subscription] = await reader.getAll(...refs);
  const memberRoles = member.get('roles');
  const holds = (role) => Array.isArray(memberRoles) && (memberRoles.includes(role) || hasWorkforceRole(memberRoles, role));
  const denied = () => new HttpsError('permission-denied', 'Vínculo ativo com esta empresa é obrigatório.');
  if (!member.exists || member.get('active') !== true || !Array.isArray(memberRoles) || !roles.some(holds)) throw denied();
  // Through the tutor role only, a petshop without the tutor app keeps the
  // tutor reading (A1-u) and refuses every tutor command.
  const viaTutor = roles.includes('TUTOR') && !roles.some((role) => role !== 'TUTOR' && holds(role));
  if (viaTutor && tutorReadOnly(tenant, subscription)) {
    if (tutorRead) return { tenant, member, subscription, readOnly: true };
    throw new HttpsError('permission-denied', TUTOR_APP_CLOSED, { reason: 'TUTOR_APP_UNAVAILABLE' });
  }
  const paused = (reason, billing) => {
    if (viaTutor) {
      if (tutorRead) return { tenant, member, subscription, readOnly: true, billing };
      throw new HttpsError('permission-denied', TUTOR_APP_CLOSED, { reason: 'TUTOR_APP_UNAVAILABLE' });
    }
    if (pausedPrincipal && principalMember(member.data())) return { tenant, member, subscription, paused: reason, billing };
    throw new HttpsError('permission-denied', ACCESS_PAUSED, { reason: 'ACCESS_PAUSED' });
  };
  // Platform suspension stays immediate; the tutor keeps reading (E2).
  if (tenant.exists && companySuspended(tenant.data()) && subscription.exists && subscription.get('tenantId') === tenant.id) return paused('SUSPENDED', null);
  if (!tenantEnabled(tenant, subscription)) throw denied();
  const billing = await tenantPhase(reader, db, tenant, subscription);
  if (billing.phase === BILLING_BLOCKED) return paused('BILLING', billing);
  return { tenant, member, subscription, billing };
}

/// Released, with a valid subscription and not blocked by an expired plan (E2).
export async function tenantOpen(reader, db, tenant, subscription) {
  return tenantEnabled(tenant, subscription) && (await tenantPhase(reader, db, tenant, subscription)).phase !== BILLING_BLOCKED;
}
export function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  return value;
}

export function tenantEnabled(tenant, subscription) {
  return tenant.exists && subscription?.exists && companyReleased(tenant.data())
    && subscription.get('tenantId') === tenant.id && subscriptionValid(subscription.data());
}

export async function accountAvailable(reader,db,uid) {
 const ref=db.doc('users/'+uid),doc=reader===db?await ref.get():await reader.get(ref);
 if(doc.get('deletionState'))throw new HttpsError('permission-denied','Esta conta está em exclusão.');
}
