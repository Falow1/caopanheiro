import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { actor, digest, localBackend, object, options } from './runtime.js';
import { purgeAt, retention } from './retention.js';

// The devices that receive the push notifications of the Equipe and SaaS
// apps. One document per device, named by the digest of its token: a device
// signed in by another person moves to that person. Renewed at each login and
// removed at the sign out; the daily purge removes the ones left behind.
const APPS = ['equipe', 'saas'];
const tokenRef = (db, token) => db.doc(`pushTokens/${digest(`push:${token}`)}`);

function deviceToken(value) {
  if (typeof value !== 'string' || value.length < 20 || value.length > 4096 || !/^[\w:.-]+$/.test(value)) {
    throw new HttpsError('invalid-argument', 'Identificador do aparelho inválido.');
  }
  return value;
}

export const registerPushToken = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  object(request.data, ['token', 'app'], 'Notificações');
  const token = deviceToken(request.data.token);
  if (!APPS.includes(request.data.app)) throw new HttpsError('invalid-argument', 'Aplicativo inválido.');
  const now = Date.now();
  await tokenRef(db, token).set({ uid, app: request.data.app, token, updatedAtMs: now, purgeAt: purgeAt(retention.pushToken, now) });
  return { registered: true };
});

export const unregisterPushToken = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  object(request.data, ['token'], 'Notificações');
  const ref = tokenRef(db, deviceToken(request.data.token));
  await db.runTransaction(async (tx) => {
    const device = await tx.get(ref);
    if (device.exists && device.get('uid') === uid) tx.delete(ref);
  });
  return { unregistered: true };
});
