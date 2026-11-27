import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { actor, identifier, invalid, localBackend, object, options, teamAccess } from './runtime.js';
import { purgeAt, retention } from './retention.js';

// Live position of the driver, kept only while one of the driver's transports of the
// petshop is on the way. One document per driver, overwritten at each report:
// no route history is kept. Only the server writes and reads it
// (firestore.rules); the tutor of a transport on the way and the team see it
// through their own queries. It moves no live signal (live_signals.js): the
// screens that show it read again on their own.
export const routeStatuses = Object.freeze(['GOING_TO_ORIGIN', 'PET_COLLECTED', 'IN_TRANSIT']);
// Reports closer than this are answered without a write.
export const MIN_REPORT_INTERVAL_MS = 5000;
const locationRef = (db, tenantId, uid) => db.doc(`tenants/${tenantId}/driverLocations/${uid}`);
const routeQuery = (db, tenantId, uid, size) => db.collection(`tenants/${tenantId}/transports`)
  .where('driverUid', '==', uid).where('status', 'in', routeStatuses).limit(size);

function coordinate(value, limit, label) {
  if (!Number.isFinite(value) || value < -limit || value > limit) invalid(`${label} inválida.`);
  return value;
}

/// Position sent by the app; accuracy in meters, as the phone reports it.
export function locationInput(data) {
  object(data, ['tenantId', 'lat', 'lng', 'accuracy'], 'Posição');
  const lat = coordinate(data.lat, 90, 'Latitude'), lng = coordinate(data.lng, 180, 'Longitude');
  const accuracy = data.accuracy == null ? null : data.accuracy;
  if (accuracy !== null && (!Number.isFinite(accuracy) || accuracy < 0 || accuracy > 100000)) invalid('Precisão inválida.');
  return { lat, lng, accuracy: accuracy === null ? null : Math.round(accuracy) };
}

/// The driver app reports its position while it has a transport on the way.
/// Without one, the stored position is removed and the app is told to stop.
export const reportDriverLocation = onCall(options, async (request) => {
  const position = locationInput(request.data);
  const db = localBackend(), uid = await actor(request), tenantId = identifier(request.data.tenantId, 'Empresa');
  return db.runTransaction(async (tx) => {
    await teamAccess(tx, db, tenantId, uid, ['DRIVER']);
    const route = await tx.get(routeQuery(db, tenantId, uid, 1));
    const ref = locationRef(db, tenantId, uid), previous = await tx.get(ref);
    if (route.empty) {
      if (previous.exists) tx.delete(ref);
      return { sharing: false, stored: false };
    }
    const now = Date.now(), last = Date.parse(previous.get('reportedAt') ?? '');
    if (previous.exists && Number.isFinite(last) && now - last < MIN_REPORT_INTERVAL_MS) return { sharing: true, stored: false };
    tx.set(ref, { ...position, driverUid: uid, tenantId, reportedAt: new Date(now).toISOString(), purgeAt: purgeAt(retention.location, now) });
    return { sharing: true, stored: true };
  });
});

/// Time from which a position belongs to this transport: when it left, or
/// when it last changed hands, so a position of the driver before is not shown.
function routeSince(job) {
  const handovers = (job.get('assignmentHistory') ?? []).map((change) => Date.parse(change.at));
  const times = [Date.parse(job.get('startedAt') ?? ''), ...handovers].filter(Number.isFinite);
  return times.length ? Math.max(...times) : null;
}

const positionJson = (doc) => ({ lat: doc.get('lat'), lng: doc.get('lng'), accuracy: doc.get('accuracy') ?? null, reportedAt: doc.get('reportedAt') });

/// Positions of the drivers of the given transports (snapshots) that are on
/// the way, by transport id. A transport stopped, or without a report since
/// it left, has none.
export async function routeLocations(reader, db, tenantId, jobs) {
  const live = jobs.filter((job) => job.exists && routeStatuses.includes(job.get('status')) && typeof job.get('driverUid') === 'string');
  const uids = [...new Set(live.map((job) => job.get('driverUid')))];
  if (!uids.length) return new Map();
  const docs = await reader.getAll(...uids.map((uid) => locationRef(db, tenantId, uid)));
  const byUid = new Map(docs.filter((doc) => doc.exists).map((doc) => [doc.id, doc]));
  const result = new Map();
  for (const job of live) {
    const doc = byUid.get(job.get('driverUid')), since = routeSince(job);
    if (!doc || (since !== null && !(Date.parse(doc.get('reportedAt')) >= since))) continue;
    result.set(job.id, positionJson(doc));
  }
  return result;
}

/// When the driver delivers the last transport on the way, the position goes
/// in the same transaction. Read part: call before the writes.
export async function prepareLocationRelease(tx, db, tenantId, uid, transportId) {
  const route = await tx.get(routeQuery(db, tenantId, uid, 2));
  return route.docs.every((doc) => doc.id === transportId) ? locationRef(db, tenantId, uid) : null;
}

/// Current position of the driver of a transport, for the team. Read on
/// demand: position reports move no live signal.
export const getTransportLocation = onCall(options, async (request) => {
  object(request.data, ['tenantId', 'transportId'], 'Consulta');
  const db = localBackend(), uid = await actor(request), tenantId = identifier(request.data.tenantId, 'Empresa');
  const transportId = identifier(request.data.transportId, 'Transporte');
  return db.runTransaction(async (tx) => {
    await teamAccess(tx, db, tenantId, uid);
    const job = await tx.get(db.doc(`tenants/${tenantId}/transports/${transportId}`));
    if (!job.exists) throw new HttpsError('not-found', 'Transporte não encontrado.');
    const location = (await routeLocations(tx, db, tenantId, [job])).get(job.id) ?? null;
    return { status: job.get('status'), onRoute: routeStatuses.includes(job.get('status')), location, checkedAt: new Date().toISOString() };
  });
});
