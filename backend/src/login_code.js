import { randomBytes, randomInt, scryptSync, timingSafeEqual } from 'node:crypto';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { actor, identifier, localBackend, object, options } from './runtime.js';
import { purgeAt, retention } from './retention.js';
import { queuePlatformEmail } from './mail_outbox.js';

/// Second step of the Tutor and Equipe login: a six-number code by e-mail,
/// with the same limits as the SaaS. In this demonstration the step can be
/// skipped in the apps, so no other call depends on it; the code goes to the
/// local outbox and no real e-mail is sent.
export const requestLoginCode = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  object(request.data, [], 'Código');
  const account = await getAuth().getUser(uid);
  if (!account.email || account.disabled) throw new HttpsError('failed-precondition', 'Conta indisponível.');
  const now = Date.now(), id = randomBytes(24).toString('hex'), code = String(randomInt(100000, 1000000));
  const salt = randomBytes(32).toString('hex'), hash = scryptSync(code, salt, 32).toString('hex');
  const limiter = db.doc(`loginCodeLimits/${uid}`);
  await db.runTransaction(async (tx) => {
    const last = await tx.get(limiter);
    if (last.exists && now - last.get('sentAt') < 60000) throw new HttpsError('resource-exhausted', 'Aguarde um minuto antes de solicitar outro código.');
    const reset = !last.exists || now - last.get('windowStart') >= 3600000;
    const count = reset ? 0 : last.get('count');
    if (count >= 5) throw new HttpsError('resource-exhausted', 'Limite de solicitações atingido. Tente mais tarde.');
    // Only the latest challenge for this account remains usable.
    tx.set(limiter, { sentAt: now, windowStart: reset ? now : last.get('windowStart'), count: count + 1, challengeId: id, purgeAt: purgeAt(retention.limit, now) });
    tx.create(db.doc(`loginCodeChallenges/${id}`), { uid, salt, hash,
      expiresAt: Timestamp.fromMillis(now + 300000), attempts: 0, consumed: false, purgeAt: purgeAt(retention.limit, now) });
  });
  await queuePlatformEmail(db, id, { uid, to: account.email,
    subject: 'Código de acesso Cãopanheiro', text: `Seu código é ${code}. Validade: cinco minutos.`,
    challengeId: id, createdAt: Timestamp.fromMillis(now), expiresAt: Timestamp.fromMillis(now + 300000) }, now);
  return { challengeId: id, delivery: 'local', expiresInSeconds: 300 };
});

export const verifyLoginCode = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  object(request.data, ['challengeId', 'code'], 'Código');
  const id = identifier(request.data.challengeId, 'Verificação', 32);
  if (typeof request.data.code !== 'string' || !/^\d{6}$/.test(request.data.code)) throw new HttpsError('invalid-argument', 'Informe os seis números do código.');
  const now = Date.now();
  const correct = await db.runTransaction(async (tx) => {
    const ref = db.doc(`loginCodeChallenges/${id}`);
    const [challenge, limiter] = await tx.getAll(ref, db.doc(`loginCodeLimits/${uid}`));
    if (!challenge.exists || challenge.get('uid') !== uid || limiter.get('challengeId') !== id
      || challenge.get('consumed') || challenge.get('expiresAt').toMillis() <= now || challenge.get('attempts') >= 5) return false;
    const match = timingSafeEqual(scryptSync(request.data.code, challenge.get('salt'), 32), Buffer.from(challenge.get('hash'), 'hex'));
    tx.update(ref, { attempts: challenge.get('attempts') + 1, ...(match ? { consumed: true } : {}) });
    if (match) tx.set(db.doc(`users/${uid}`), { loginVerifiedAt: FieldValue.serverTimestamp() }, { merge: true });
    return match;
  });
  if (!correct) throw new HttpsError('invalid-argument', 'Código incorreto, expirado ou já utilizado.');
  return { verified: true };
});
