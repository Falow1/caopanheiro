import { randomBytes, randomInt, scryptSync, timingSafeEqual } from 'node:crypto';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { actor, digest, identifier, localBackend, object, options } from './runtime.js';
import { purgeAt, retention } from './retention.js';
import { queuePlatformEmail } from './mail_outbox.js';

async function administrator(db, uid) {
  const doc = await db.doc(`platformAdmins/${uid}`).get();
  if (!doc.exists || doc.get('active') !== true || doc.get('role') !== 'ADMIN') {
    throw new HttpsError('permission-denied', 'Acesso administrativo obrigatório.');
  }
  return doc;
}
export async function emailSessionValid(request, db, uid) {
  const token = request.auth.token, session = token.saasEmailSession;
  if (typeof session !== 'string' || !/^[a-f0-9]{64}$/.test(session)) return false;
  const doc = await db.doc(`platformEmailSessions/${digest(session)}`).get();
  return doc.exists && doc.get('uid') === uid && doc.get('expiresAt').toMillis() > Date.now()
    && token.saasEmailExpiresAt === Math.floor(doc.get('expiresAt').toMillis() / 1000);
}
export async function requireEmailSession(request, db, uid) {
  if (!await emailSessionValid(request, db, uid)) {
    throw new HttpsError('permission-denied', 'Confirme o código enviado ao seu e-mail para acessar a administração.');
  }
}
export const requestSaasEmailCode = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  object(request.data, [], 'Código'); await administrator(db, uid);
  const account = await getAuth().getUser(uid);
  if (!account.email || account.disabled) throw new HttpsError('failed-precondition', 'Conta indisponível.');
  const now = Date.now(), id = randomBytes(24).toString('hex'), code = String(randomInt(100000, 1000000));
  const salt = randomBytes(32).toString('hex'), hash = scryptSync(code, salt, 32).toString('hex');
  const limiter = db.doc(`platformEmailLimits/${uid}`);
  await db.runTransaction(async (tx) => {
    const last = await tx.get(limiter);
    if (last.exists && now - last.get('sentAt') < 60000) throw new HttpsError('resource-exhausted', 'Aguarde um minuto antes de solicitar outro código.');
    const reset = !last.exists || now - last.get('windowStart') >= 3600000;
    const count = reset ? 0 : last.get('count');
    if (count >= 5) throw new HttpsError('resource-exhausted', 'Limite de solicitações atingido. Tente mais tarde.');
    // Only the latest challenge for this account remains usable.
    tx.set(limiter, { sentAt: now, windowStart: reset ? now : last.get('windowStart'), count: count + 1, challengeId: id, purgeAt: purgeAt(retention.limit, now) });
    tx.create(db.doc(`platformEmailChallenges/${id}`), { uid, email: account.email, salt, hash,
      expiresAt: Timestamp.fromMillis(now + 300000), attempts: 0, consumed: false, purgeAt: purgeAt(retention.limit, now) });
  });
  // Local delivery adapter: never sends real mail or exposes the code to the app.
  // Production delivery requires a separately configured mail service.
  await queuePlatformEmail(db, id, { uid, to: account.email,
    subject: 'Código de acesso Cãopanheiro', text: `Seu código é ${code}. Validade: cinco minutos.`,
    challengeId: id, createdAt: Timestamp.fromMillis(now), expiresAt: Timestamp.fromMillis(now + 300000) }, now);
  return { challengeId: id, delivery: 'local', expiresInSeconds: 300 };
});
export const verifySaasEmailCode = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  object(request.data, ['challengeId', 'code'], 'Código'); await administrator(db, uid);
  const id = identifier(request.data.challengeId, 'Verificação', 32);
  if (typeof request.data.code !== 'string' || !/^\d{6}$/.test(request.data.code)) throw new HttpsError('invalid-argument', 'Informe os seis números do código.');
  const now = Date.now(), session = randomBytes(32).toString('hex'), expiresAt = Timestamp.fromMillis(now + 8 * 3600000);
  const outcome = await db.runTransaction(async (tx) => {
    const ref = db.doc(`platformEmailChallenges/${id}`);
    const [challenge, limiter] = await tx.getAll(ref, db.doc(`platformEmailLimits/${uid}`));
    if (!challenge.exists || challenge.get('uid') !== uid || limiter.get('challengeId') !== id
      || challenge.get('consumed') || challenge.get('expiresAt').toMillis() <= now || challenge.get('attempts') >= 5) return false;
    const correct = timingSafeEqual(scryptSync(request.data.code, challenge.get('salt'), 32), Buffer.from(challenge.get('hash'), 'hex'));
    tx.update(ref, { attempts: challenge.get('attempts') + 1, ...(correct ? { consumed: true } : {}) });
    if (correct) tx.create(db.doc(`platformEmailSessions/${digest(session)}`), { uid, expiresAt, verifiedAt: Timestamp.fromMillis(now), purgeAt: purgeAt(retention.afterSession, expiresAt.toMillis()) });
    return correct;
  });
  if (!outcome) throw new HttpsError('invalid-argument', 'Código incorreto, expirado ou já utilizado.');
  const customToken = await getAuth().createCustomToken(uid, { saasEmailSession: session, saasEmailExpiresAt: Math.floor(expiresAt.toMillis() / 1000) });
  return { customToken };
});
