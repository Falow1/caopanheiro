import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { FieldValue } from 'firebase-admin/firestore';
import { localBackend, options } from './runtime.js';

/// Change signals for the live refresh of the apps. A signal is a document
/// with only a counter and the time of the last change: it never carries
/// business data. Apps listen to it and, when it moves, read again through
/// the authorized server queries they already use.
///
/// Signals per petshop, in tenants/{tenantId}/liveSignals:
/// - team: any operational change, read by active staff;
/// - catalog: services, schedule, policies and company status, read by any
///   active link, tutors included;
/// - tutor-{uid}: records of that tutor's customer, read only by that UID.
/// The platform signal platformSignals/admin is read by active administrators.
///
/// The rules below run in two ways: from the Firestore triggers of this file,
/// in Cloud Functions, and from backend/server, which has no triggers and
/// applies the same rules to the documents each call wrote (signalPaths).

// Internal records no screen shows. Each one is written together with a
// record that already moves the signals (appointment, transport, member or
// customer), so leaving them out loses no refresh and saves one trigger run
// and one reload of every connected app per write.
const ignored = new Set(['liveSignals', 'entityCommandReceipts', 'noticeMarkers', 'transportQuotes', 'transportPetLocks',
  'serviceCommandReceipts', 'recordSequences', 'managerActivationEvents', 'workforceEvents', 'petCustody', 'tutorInvites',
  // Driver position, reported every few seconds on the way: the tutor card and
  // the team read it on their own (driver_location.js), without a reload.
  'driverLocations']);
// Removed only by the automatic cleanup (TTL), after they stopped being shown:
// getNotices already hides expired notices, so the deletion changes no screen.
const purgedOnDelete = new Set(['notices']);
const catalog = new Set(['services', 'settings', 'blocks', 'scheduleDays', 'professionals']);
// Petshop records whose own fields say which tutors see them.
// petBlocks: "Não atender este pet", one document per customer (customerId).
const tutorRecords = new Set(['customers', 'appointments', 'transports', 'transportRequests', 'notices', 'members', 'petBlocks']);
const signalOptions = { region: options.region, maxInstances: options.maxInstances };

/// Fields the rules read from a changed document, before and after the change.
export const SIGNAL_FIELDS = Object.freeze(['customerId', 'tutorUid', 'appointmentId', 'channel', 'roles', 'tenantId', 'tenantIds', 'waitingTenantIds']);

function bump(db, path) {
  return db.doc(path).set({ revision: FieldValue.increment(1), changedAtMs: Date.now() }, { merge: true });
}

/// Moves each signal once, however many changes asked for it.
export function bumpSignals(db, paths) {
  return Promise.all([...new Set(paths)].map((path) => bump(db, path)));
}

const validId = (id) => typeof id === 'string' && id.length > 0 && id.length <= 128;

const values = (event, field) => [event.data?.before, event.data?.after]
  .filter((snapshot) => snapshot?.exists).map((snapshot) => snapshot.get(field))
  .filter(validId);

async function customerTutors(db, tenantId, customerIds) {
  const ids = [...new Set(customerIds)];
  if (!ids.length) return [];
  const docs = await db.getAll(...ids.map((id) => db.doc(`tenants/${tenantId}/customers/${id}`)));
  return docs.filter((doc) => doc.exists).map((doc) => doc.get('tutorUid'));
}

async function appointmentCustomers(db, tenantId, appointmentIds) {
  const ids = [...new Set(appointmentIds)];
  if (!ids.length) return [];
  const docs = await db.getAll(...ids.map((id) => db.doc(`tenants/${tenantId}/appointments/${id}`)));
  return docs.filter((doc) => doc.exists).map((doc) => doc.get('customerId'));
}

/// Tutors whose own screens show the changed record.
export async function affectedTutors(db, tenantId, collection, event) {
  const docId = event.params.docId;
  if (collection === 'customers') return values(event, 'tutorUid');
  if (collection === 'appointments' || collection === 'petBlocks') return customerTutors(db, tenantId, values(event, 'customerId'));
  if (collection === 'transports' || collection === 'transportRequests') {
    const direct = values(event, 'tutorUid');
    const customers = [...values(event, 'customerId'),
      ...await appointmentCustomers(db, tenantId, values(event, 'appointmentId'))];
    return [...direct, ...await customerTutors(db, tenantId, customers)];
  }
  if (collection === 'notices') {
    return values(event, 'channel').filter((channel) => channel.startsWith('TUTOR:')).map((channel) => channel.slice(6));
  }
  if (collection === 'members') {
    const roles = [event.data?.before, event.data?.after].filter((doc) => doc?.exists).flatMap((doc) => doc.get('roles') ?? []);
    return Array.isArray(roles) && roles.includes('TUTOR') ? [docId] : [];
  }
  return [];
}

const validUid = (uid) => typeof uid === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(uid);

async function tenantRecordSignals(db, { tenantId, collection, docId }, event) {
  if (ignored.has(collection)) return [];
  if (purgedOnDelete.has(collection) && !event.data?.after?.exists) return [];
  const tutors = [...new Set(await affectedTutors(db, tenantId, collection, { ...event, params: { ...event.params, docId } }))].filter(validUid);
  return [`tenants/${tenantId}/liveSignals/team`,
    ...(catalog.has(collection) ? [`tenants/${tenantId}/liveSignals/catalog`] : []),
    ...tutors.map((uid) => `tenants/${tenantId}/liveSignals/tutor-${uid}`)];
}

/// Company and subscription status change what every app of the petshop can
/// do, and are shown in the platform administration.
const tenantSignals = (tenantId) => [`tenants/${tenantId}/liveSignals/team`, `tenants/${tenantId}/liveSignals/catalog`, 'platformSignals/admin'];

const subscriptionSignals = (event) => ['platformSignals/admin', ...[...new Set(values(event, 'tenantId'))]
  .flatMap((tenantId) => [`tenants/${tenantId}/liveSignals/team`, `tenants/${tenantId}/liveSignals/catalog`])];

const supportRequestSignals = (event) => ['platformSignals/admin',
  ...[...new Set(values(event, 'tenantId'))].map((tenantId) => `tenants/${tenantId}/liveSignals/team`)];

/// The plan screen of each subscribed petshop shows the plan name, price and
/// limits, so the team signal of those companies moves too.
async function planSignals(db, planId) {
  const page = await db.collection('subscriptions').where('planId', '==', planId).select('tenantId').get();
  const tenants = [...new Set(page.docs.map((doc) => doc.get('tenantId')))].filter(validId);
  return ['platformSignals/admin', ...tenants.map((tenantId) => `tenants/${tenantId}/liveSignals/team`)];
}

// Subscription of the principal manager (A1): its petshops show the plan,
// and the SaaS lists the pending items.
function billingAccountSignals(event) {
  const ids = [event.data?.before, event.data?.after].filter((snapshot) => snapshot?.exists)
    .flatMap((snapshot) => [...(snapshot.get('tenantIds') ?? []), ...(snapshot.get('waitingTenantIds') ?? [])])
    .filter(validId);
  return ['platformSignals/admin', ...[...new Set(ids)].map((tenantId) => `tenants/${tenantId}/liveSignals/team`)];
}

/// Whether the rules read fields of a document at this path. The others move
/// their signals from the path alone.
export function signalNeedsFields(path) {
  const parts = path.split('/');
  if (parts.length === 4 && parts[0] === 'tenants') return tutorRecords.has(parts[2]);
  return parts.length === 2 && ['subscriptions', 'supportRequests', 'billingAccounts'].includes(parts[0]);
}

/// Signals moved by a change of the document at `path`. `before` and `after`
/// are snapshots (exists and get(field)) of the document around the change;
/// paths no rule covers move nothing, as no trigger listens to them.
export async function signalPaths(db, path, before, after) {
  const parts = path.split('/');
  const event = { params: {}, data: { before, after } };
  if (parts.length === 4 && parts[0] === 'tenants') {
    return tenantRecordSignals(db, { tenantId: parts[1], collection: parts[2], docId: parts[3] }, event);
  }
  if (parts.length !== 2) return [];
  const [collection, id] = parts;
  if (collection === 'tenants') return tenantSignals(id);
  if (collection === 'subscriptions') return subscriptionSignals(event);
  if (collection === 'supportRequests') return supportRequestSignals(event);
  if (collection === 'plans') return planSignals(db, id);
  if (collection === 'platformAudit' || collection === 'billingRequests') return ['platformSignals/admin'];
  if (collection === 'billingAccounts') return billingAccountSignals(event);
  return [];
}

export const signalTenantRecord = onDocumentWritten(
  { ...signalOptions, document: 'tenants/{tenantId}/{collection}/{docId}' },
  async (event) => {
    const { tenantId, collection, docId } = event.params;
    if (ignored.has(collection)) return;
    if (purgedOnDelete.has(collection) && !event.data?.after?.exists) return;
    const db = localBackend();
    await bumpSignals(db, await tenantRecordSignals(db, { tenantId, collection, docId }, event));
  });

export const signalTenant = onDocumentWritten(
  { ...signalOptions, document: 'tenants/{tenantId}' },
  async (event) => { await bumpSignals(localBackend(), tenantSignals(event.params.tenantId)); });

export const signalSubscription = onDocumentWritten(
  { ...signalOptions, document: 'subscriptions/{subscriptionId}' },
  async (event) => { await bumpSignals(localBackend(), subscriptionSignals(event)); });

export const signalSupportRequest = onDocumentWritten(
  { ...signalOptions, document: 'supportRequests/{supportRequestId}' },
  async (event) => { await bumpSignals(localBackend(), supportRequestSignals(event)); });

export const signalPlan = onDocumentWritten(
  { ...signalOptions, document: 'plans/{planId}' },
  async (event) => { const db = localBackend(); await bumpSignals(db, await planSignals(db, event.params.planId)); });

export const signalPlatformAudit = onDocumentWritten(
  { ...signalOptions, document: 'platformAudit/{auditId}' },
  async () => { await bumpSignals(localBackend(), ['platformSignals/admin']); });

export const signalBillingAccount = onDocumentWritten(
  { ...signalOptions, document: 'billingAccounts/{accountId}' },
  async (event) => { await bumpSignals(localBackend(), billingAccountSignals(event)); });

export const signalBillingRequest = onDocumentWritten(
  { ...signalOptions, document: 'billingRequests/{requestId}' },
  async () => { await bumpSignals(localBackend(), ['platformSignals/admin']); });
