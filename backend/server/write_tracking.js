import { AsyncLocalStorage } from 'node:async_hooks';
import { Firestore, Query, Transaction, WriteBatch } from 'firebase-admin/firestore';
import { SIGNAL_FIELDS, bumpSignals, signalNeedsFields, signalPaths } from '../src/live_signals.js';
import { deliverPushes } from './push_delivery.js';

// Cloud Functions moves the live signals with Firestore triggers, which a
// project on the Spark plan cannot deploy. Here each call runs with a record of
// the documents it committed and of the signal fields (SIGNAL_FIELDS) of the
// documents it read before writing them; when the call ends, the rules of
// live_signals.js are applied to that record. Only writes made through this
// process move signals: a change made in the console or by a script does not.
//
// The record follows the Admin SDK at three points of @google-cloud/firestore
// (version fixed by pnpm-lock.yaml): WriteBatch._commit, the single commit of
// batches, transactions and document writes, with the paths of its _ops; and
// the reads of Transaction.get/getAll, Firestore.getAll and Query.get. A
// transaction that retries resets its batch, so only the committed attempt
// counts. backend/test/fly-server.test.mjs checks these points. The same
// record, with the documents the call created, gives the push notifications
// of server/push_delivery.js.

const storage = new AsyncLocalStorage();
const UNSUPPORTED = 'Versão do Firestore Admin sem os pontos de acompanhamento esperados.';
let installed = false;

const fieldsOf = (snapshot) => (snapshot.exists
  ? Object.fromEntries(SIGNAL_FIELDS.map((field) => [field, snapshot.get(field)]).filter(([, value]) => value !== undefined))
  : null);

/// Keeps the state before the call of each document the rules read fields
/// of; later reads of a document the call already wrote are not the "before".
function remember(store, result) {
  if (!result) return;
  if (Array.isArray(result)) { for (const item of result) remember(store, item); return; }
  if (Array.isArray(result.docs)) { for (const doc of result.docs) remember(store, doc); return; }
  const path = result.ref?.path;
  if (typeof path !== 'string' || typeof result.exists !== 'boolean') return;
  if (!signalNeedsFields(path) || store.before.has(path) || store.written.has(path)) return;
  store.before.set(path, fieldsOf(result));
}

function followReads(prototype, name) {
  const original = prototype[name];
  prototype[name] = function followedRead(...args) {
    const store = storage.getStore();
    const result = original.apply(this, args);
    if (!store) return result;
    return Promise.resolve(result).then((value) => { remember(store, value); return value; });
  };
}

/// Patches the Admin SDK once per process. Outside a tracked call nothing
/// changes: reads and writes go straight to the original methods.
export function installWriteTracking() {
  if (installed) return;
  installed = true;
  followReads(Transaction.prototype, 'get');
  followReads(Transaction.prototype, 'getAll');
  followReads(Firestore.prototype, 'getAll');
  followReads(Query.prototype, 'get');
  const commit = WriteBatch.prototype._commit;
  if (typeof commit !== 'function') throw new Error(UNSUPPORTED);
  WriteBatch.prototype._commit = async function trackedCommit(...args) {
    const store = storage.getStore();
    if (!store) return commit.apply(this, args);
    // Refuse the call rather than commit writes whose signals would be lost.
    if (!Array.isArray(this._ops)) throw new Error(UNSUPPORTED);
    const ops = this._ops.map(({ docPath, op }) => ({ path: docPath, op }));
    const created = ops.filter(({ op }) => op().currentDocument?.exists === false).map(({ path }) => path);
    // An update of a document the call did not read: read its fields now, just
    // before the commit, so a tutor or petshop that leaves it is still told.
    const unknown = [...new Set(ops.filter(({ path, op }) => signalNeedsFields(path) && !store.before.has(path)
      && !store.written.has(path) && op().currentDocument?.exists !== false).map(({ path }) => path))];
    if (unknown.length) {
      const firestore = this._firestore;
      const docs = await storage.exit(() => firestore.getAll(...unknown.map((path) => firestore.doc(path)), { fieldMask: [...SIGNAL_FIELDS] }));
      for (const doc of docs) store.before.set(doc.ref.path, fieldsOf(doc));
    }
    for (const { path } of ops) if (!store.before.has(path) && signalNeedsFields(path)) store.before.set(path, null);
    const result = await commit.apply(this, args);
    for (const { path } of ops) store.written.add(path);
    for (const path of created) store.created?.add(path);
    return result;
  };
}

/// Runs `work` with its own record of committed writes.
export async function tracked(work) {
  const store = { written: new Set(), created: new Set(), before: new Map() };
  const result = await storage.run(store, work);
  return { result, store };
}

const snapshotOf = (data) => ({ exists: data != null, get: (field) => data?.[field] });

/// Signals the committed writes of a record move, by the rules of
/// live_signals.js. Reads the current fields of the written documents those
/// rules look at (one read per document, as a trigger receives them).
export async function signalChanges(db, store) {
  const paths = [...store.written];
  if (!paths.length) return [];
  return storage.exit(async () => {
    const needing = paths.filter(signalNeedsFields);
    const docs = needing.length ? await db.getAll(...needing.map((path) => db.doc(path)), { fieldMask: [...SIGNAL_FIELDS] }) : [];
    const after = new Map(docs.map((doc) => [doc.ref.path, fieldsOf(doc)]));
    const signals = [];
    for (const path of paths) {
      signals.push(...await signalPaths(db, path, snapshotOf(store.before.get(path)), snapshotOf(after.get(path))));
    }
    return [...new Set(signals)];
  });
}

/// Runs `work` and then moves the signals of what it committed, even when it
/// failed after committing, and sends its push notifications. A failure to
/// move a signal or to send a push is logged and never changes the result of
/// the call.
export async function withSignals(db, work, log = console, push = deliverPushes) {
  const store = { written: new Set(), created: new Set(), before: new Map() };
  try {
    return await storage.run(store, work);
  } finally {
    try {
      const signals = await signalChanges(db, store);
      if (signals.length) await storage.exit(() => bumpSignals(db, signals));
    } catch (error) {
      log.error?.('Falha ao mover os sinais de atualização.', error?.message ?? error);
    }
    try {
      if (store.written.size) await storage.exit(() => push(db, store));
    } catch (error) {
      log.error?.('Falha ao enviar as notificações.', error?.message ?? error);
    }
  }
}
