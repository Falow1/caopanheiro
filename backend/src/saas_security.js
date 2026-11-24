import { FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { onRequest, HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { readFileSync } from 'node:fs';
import { requireEmailSession } from './saas_email.js';
import { actor, backendEnvironment, digest, localBackend, object, options } from './runtime.js';
import { checkPassword } from './password_check.js';

export async function requirePlatformAdmin(db, uid) {
  const admin = await db.doc(`platformAdmins/${uid}`).get();
  if (!admin.exists || admin.get('active') !== true || admin.get('role') !== 'ADMIN') {
    throw new HttpsError('permission-denied', 'Acesso administrativo da plataforma obrigatório.');
  }
  return admin;
}
export async function securityEvent(db, uid, action, data = {}, id) {
  const admin = await requirePlatformAdmin(db, uid);
  const value = { action, actorUid: uid, admin: admin.get('name') ?? uid, entity: 'Conta administrativa',
    tenantId: null, result: 'Confirmado', createdAt: FieldValue.serverTimestamp(), ...data };
  const ref = id ? db.collection('platformAudit').doc(id) : db.collection('platformAudit').doc();
  if (id) {
    await db.runTransaction(async (tx) => { const old = await tx.get(ref); if (!old.exists) tx.create(ref, value); });
  } else await ref.create(value);
}
export const recordSaasSession = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  await requireEmailSession(request, db, uid);
  object(request.data, [], 'Sessão');
  await securityEvent(db, uid, 'Login administrativo', {}, digest(`login:${uid}:${request.auth.token.auth_time}`));
  return { recorded: true };
});
export const changeSaasPassword = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  await requireEmailSession(request, db, uid);
  object(request.data, ['currentPassword', 'password'], 'Senha');
  await requirePlatformAdmin(db, uid);
  const password = request.data.password;
  if (typeof password !== 'string' || password.length < 8 || password.length > 128) {
    throw new HttpsError('invalid-argument', 'Use uma senha de 8 a 128 caracteres.');
  }
  if (typeof request.data.currentPassword !== 'string' || request.data.currentPassword.length > 128) {
    throw new HttpsError('invalid-argument', 'Confira a senha atual.');
  }
  const account = await getAuth().getUser(uid);
  const confirmation = await checkPassword(account.email, request.data.currentPassword, { returnSecureToken: false });
  if (!confirmation.ok) {
    await securityEvent(db, uid, 'Confirmação de senha rejeitada', { result: 'Rejeitado' },
      digest(`password-denied:${uid}:${Math.floor(Date.now() / 60000)}`));
    throw new HttpsError('invalid-argument', 'Confira a senha atual.');
  }
  const verified = await confirmation.json();
  if (verified.localId !== uid) throw new HttpsError('permission-denied', 'Identidade divergente.');
  const operation = db.collection('platformAudit').doc();
  const admin = await requirePlatformAdmin(db, uid);
  await operation.create({ action: 'Alteração de senha', actorUid: uid, admin: admin.get('name') ?? uid,
    entity: 'Conta administrativa', tenantId: null, result: 'Solicitada', createdAt: FieldValue.serverTimestamp() });
  let changed = false;
  try {
    await getAuth().updateUser(uid, { password }); changed = true;
    await getAuth().revokeRefreshTokens(uid);
    let sessions;
    do {
      sessions = await db.collection('platformEmailSessions').where('uid', '==', uid).limit(400).get();
      if (!sessions.empty) { const batch = db.batch(); for (const doc of sessions.docs) batch.delete(doc.ref); await batch.commit(); }
    } while (sessions.size === 400);
    await operation.update({ result: 'Confirmado', confirmedAt: FieldValue.serverTimestamp() });
    return { changed: true, signInRequired: true };
  } catch (error) {
    await operation.update({ result: changed ? 'Senha alterada; verificar encerramento das sessões' : 'Não concluída' }).catch(() => {});
    throw new HttpsError('internal', changed
      ? 'A senha foi alterada. Entre novamente; o encerramento das outras sessões precisa ser conferido.'
      : 'Não foi possível confirmar a alteração. Confira o acesso antes de repetir.');
  }
});

async function probe(action) {
  const start = performance.now();
  try { await action(); return { available: true, latencyMs: Math.round(performance.now() - start) }; }
  catch { return { available: false, latencyMs: Math.round(performance.now() - start) }; }
}
export const getSaasHealth = onCall(options, async (request) => {
  const db = localBackend(), uid = await actor(request);
  await requireEmailSession(request, db, uid);
  object(request.data, [], 'Saúde'); await requirePlatformAdmin(db, uid);
  const [firestore, auth] = await Promise.all([
    probe(() => db.collection('plans').limit(1).get()), probe(() => getAuth().listUsers(1)),
  ]);
  // Only backend/ is deployed: the version is the general version of its own package.json.
  const version = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8')).version ?? null;
  // FLY_APP_NAME exists only on a Fly.io machine (branch dev-banco-fly).
  const server = process.env.FLY_APP_NAME ? ', servidor Fly.io' : '';
  const environment = (backendEnvironment() === 'local' ? 'Firebase local' : `Firebase ${process.env.GCLOUD_PROJECT}`) + server;
  return { checkedAt: new Date().toISOString(), environment, version,
    functions: { available: true, processUptimeSeconds: Math.floor(process.uptime()) }, firestore, auth,
    queue: { configured: false }, ready: firestore.available && auth.available };
});
export const live = onRequest(options, (_request, response) => {
  localBackend(); response.status(200).json({ status: 'up' });
});
export const ready = onRequest(options, async (_request, response) => {
  const db = localBackend();
  const checks = await Promise.all([probe(() => db.collection('plans').limit(1).get()), probe(() => getAuth().listUsers(1))]);
  const available = checks.every((c) => c.available);
  response.status(available ? 200 : 503).json({ status: available ? 'ready' : 'unavailable' });
});
