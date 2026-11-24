import { Timestamp } from 'firebase-admin/firestore';
import { applyDueCancellations } from '../src/billing.js';

// Daily work that Cloud Functions would leave to the platform: on the Spark
// plan Firestore has no TTL policy and there is no scheduler, so this server
// deletes the temporary records past their purgeAt (backend/src/retention.js)
// and the notices past their expiresAt, and applies the cancellations at the
// end of the cycle (runBillingRoutine). It runs at most once a day, the first
// time the server is up after 24 hours, or on demand with `node server/main.js job`.

const DAY = 86400000;
// Daily ceiling of deletions, below the 20,000 of the Spark plan.
export const MAX_DELETES_PER_RUN = 5000;
const PAGE = 250;

/// Top-level collections with purgeAt.
export const PURGE_COLLECTIONS = Object.freeze(['platformCommandReceipts', 'billingReceipts', 'managerInvitationOutbox',
  'teamLoginEmailOutbox', 'platformEmailOutbox', 'teamAuthLimits', 'platformEmailLimits', 'platformEmailChallenges',
  'platformEmailSessions', 'mapSearchCache']);
/// Collections inside each petshop (tenants/{id}/...) with purgeAt, read as
/// collection groups: the query needs the collection group index on purgeAt
/// declared in firestore.indexes.json.
export const PURGE_GROUPS = Object.freeze(['entityCommandReceipts', 'serviceCommandReceipts', 'transportQuotes', 'tutorInvites']);

async function deleteMatching(db, query, budget) {
  let deleted = 0;
  while (deleted < budget) {
    const page = await query.limit(Math.min(PAGE, budget - deleted)).get();
    if (page.empty) break;
    const batch = db.batch();
    for (const doc of page.docs) batch.delete(doc.ref);
    await batch.commit();
    deleted += page.size;
    if (page.size < PAGE) break;
  }
  return deleted;
}

/// Deletes what is past its date, within MAX_DELETES_PER_RUN; what is left
/// waits for the next day. Returns the count per collection.
export async function purgeExpired(db, now = Date.now(), budget = MAX_DELETES_PER_RUN) {
  const limit = Timestamp.fromMillis(now);
  const queries = [
    ...PURGE_COLLECTIONS.map((name) => [name, db.collection(name).where('purgeAt', '<=', limit)]),
    ...PURGE_GROUPS.map((name) => [name, db.collectionGroup(name).where('purgeAt', '<=', limit)]),
    // Notices are hidden by getNotices after expiresAt (60 days).
    ['notices', db.collectionGroup('notices').where('expiresAt', '<=', limit)],
  ];
  const counts = {}; let left = budget;
  for (const [name, query] of queries) {
    if (left <= 0) break;
    const deleted = await deleteMatching(db, query, left);
    if (deleted) counts[name] = (counts[name] ?? 0) + deleted;
    left -= deleted;
  }
  return counts;
}

/// Claims the run of the day in platformJobs/daily, closed to the apps by the
/// Rules; two servers starting together run it once.
export async function claimDailyRun(db, now = Date.now()) {
  const ref = db.doc('platformJobs/daily');
  return db.runTransaction(async (tx) => {
    const last = (await tx.get(ref)).get('startedAt')?.toMillis?.() ?? 0;
    if (now - last < DAY) return false;
    tx.set(ref, { startedAt: Timestamp.fromMillis(now) }, { merge: true });
    return true;
  });
}

/// The daily work. `force` skips the claim, for the command line. `track`
/// runs the cancellations, which change subscriptions and so move signals; the
/// deletions move none (expired notices and internal records).
export async function runDailyJobs(db, { now = Date.now(), force = false, track = (work) => work() } = {}) {
  if (!force && !(await claimDailyRun(db, now))) return null;
  const purged = await purgeExpired(db, now);
  const cancellationsApplied = await track(() => applyDueCancellations(db, now));
  await db.doc('platformJobs/daily').set({ finishedAt: Timestamp.fromMillis(Date.now()), purged, cancellationsApplied }, { merge: true });
  return { purged, cancellationsApplied };
}
