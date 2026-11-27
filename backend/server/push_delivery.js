import { FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { backendEnvironment } from '../src/runtime.js';
import { purgeAt, retention } from '../src/retention.js';
import { hasWorkforceRole } from '../src/workforce_policy.js';

// Push notifications of the Equipe and SaaS apps, sent by this server after
// each call from what the call committed (as the live signals): every new
// in-app notice goes to the team app of the people of its channel, and the
// new subscription and support requests of the petshops go to the platform
// administrators. Only writes made through this process send pushes. In the
// emulators nothing is sent: the push is recorded in pushLocalOutbox.

const NOTICE = /^tenants\/([^/]+)\/notices\/([^/]+)$/;
const BILLING = /^billingRequests\/([^/]+)$/;
const SUPPORT = /^supportRequests\/([^/]+)$/;
const BILLING_TEXT = { PLAN_CHANGE: 'Troca de plano a confirmar.', CHARGE: 'Pagamento a confirmar.',
  REFUND: 'Devolução a registrar.', RENEWAL: 'Renovação a confirmar.' };
const DEAD = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);
const IN_LIMIT = 30;
const holds = (roles, role) => Array.isArray(roles) && (roles.includes(role) || hasWorkforceRole(roles, role));
const clip = (value, size) => String(value ?? '').slice(0, size);
const strings = (data) => Object.fromEntries(Object.entries(data).filter(([, value]) => value != null && value !== '')
  .map(([key, value]) => [key, String(value)]));

/// People of a notice channel who use the team app; never its author.
async function noticeRecipients(db, tenantId, notice) {
  const channel = String(notice.get('channel') ?? ''), author = notice.get('actorUid');
  let uids = [];
  if (channel === 'TEAM') {
    const members = await db.collection(`tenants/${tenantId}/members`).where('active', '==', true).limit(300).get();
    uids = members.docs.filter((member) => holds(member.get('roles'), 'MANAGER') || holds(member.get('roles'), 'ATTENDANT'))
      .map((member) => member.id);
  } else {
    const [role, uid] = channel.split(':');
    if (['TEAM', 'PROFESSIONAL', 'DRIVER'].includes(role) && uid) uids = [uid];
  }
  return uids.filter((uid) => uid !== author);
}

async function platformAdmins(db) {
  const admins = await db.collection('platformAdmins').where('active', '==', true).limit(100).get();
  return admins.docs.filter((admin) => admin.get('role') === 'ADMIN').map((admin) => admin.id);
}

/// The pushes a call announces, from the paths it created and wrote.
export async function pushesOf(db, store) {
  const created = store.created ?? new Set(), pushes = [];
  for (const path of created) {
    let match;
    if ((match = NOTICE.exec(path))) {
      const notice = await db.doc(path).get();
      if (!notice.exists) continue;
      const uids = await noticeRecipients(db, match[1], notice);
      if (uids.length) pushes.push({ app: 'equipe', uids, title: notice.get('title'), body: notice.get('text'),
        data: { kind: 'NOTICE', tenantId: match[1], type: notice.get('type'), appointmentId: notice.get('appointmentId'),
          transportId: notice.get('transportId'), supportRequestId: notice.get('supportRequestId') } });
    } else if ((match = BILLING.exec(path))) {
      const item = await db.doc(path).get();
      if (!item.exists || item.get('status') !== 'PENDING') continue;
      pushes.push({ app: 'saas', platform: true, author: item.get('createdByPlatform'), title: 'Pedido de assinatura',
        body: BILLING_TEXT[item.get('kind')] ?? 'Pedido aguardando a plataforma.', data: { kind: 'BILLING_REQUEST', billingRequestId: match[1] } });
    } else if ((match = SUPPORT.exec(path))) {
      const item = await db.doc(path).get();
      if (!item.exists) continue;
      pushes.push({ app: 'saas', platform: true, title: 'Novo pedido de suporte',
        body: `${clip(item.get('tenantName'), 80) || 'Um petshop'} abriu um pedido de suporte.`, data: { kind: 'SUPPORT', supportRequestId: match[1] } });
    }
  }
  // A message of the petshop in a support request already open.
  for (const path of store.written ?? []) {
    const match = SUPPORT.exec(path);
    if (!match || created.has(path)) continue;
    const item = await db.doc(path).get();
    const replies = item.exists ? item.get('replies') ?? [] : [];
    const last = replies[replies.length - 1];
    if (last?.from === 'TENANT' && last.at === item.get('updatedAt')) {
      pushes.push({ app: 'saas', platform: true, title: 'Nova mensagem no suporte',
        body: `${clip(item.get('tenantName'), 80) || 'Um petshop'} respondeu um pedido de suporte.`, data: { kind: 'SUPPORT', supportRequestId: match[1] } });
    }
  }
  return pushes;
}

async function devicesOf(db, uids, app) {
  const devices = [];
  const unique = [...new Set(uids)];
  for (let index = 0; index < unique.length; index += IN_LIMIT) {
    const page = await db.collection('pushTokens').where('uid', 'in', unique.slice(index, index + IN_LIMIT)).get();
    devices.push(...page.docs.filter((doc) => doc.get('app') === app));
  }
  return devices;
}

/// Firebase Cloud Messaging: the error code of each token, null when sent.
export async function sendWithFcm(tokens, { title, body, data }) {
  const response = await getMessaging().sendEachForMulticast({ tokens, data,
    notification: { title, body },
    android: { priority: 'high', notification: { icon: 'ic_stat_notification', color: '#176B65' } } });
  return response.responses.map((item) => (item.success ? null : item.error?.code ?? 'unknown'));
}

/// Sends the pushes of a call. Tokens the service says no longer exist are
/// removed. Returns how many devices were reached (or recorded locally).
export async function deliverPushes(db, store, { send = sendWithFcm, local = backendEnvironment() === 'local' } = {}) {
  const pushes = await pushesOf(db, store);
  let reached = 0;
  for (const push of pushes) {
    const uids = (push.platform ? await platformAdmins(db) : push.uids).filter((uid) => uid !== push.author);
    const devices = uids.length ? await devicesOf(db, uids, push.app) : [];
    if (!devices.length) continue;
    const message = { title: clip(push.title, 120), body: clip(push.body, 240), data: strings(push.data) };
    if (local) {
      const now = Date.now();
      await db.collection('pushLocalOutbox').add({ app: push.app, uids: [...new Set(devices.map((doc) => doc.get('uid')))],
        devices: devices.length, ...message, createdAt: FieldValue.serverTimestamp(), purgeAt: purgeAt(retention.pushLocal, now) });
      reached += devices.length;
      continue;
    }
    const results = await send(devices.map((doc) => doc.get('token')), message);
    const dead = devices.filter((_, index) => DEAD.has(results[index]));
    reached += results.filter((code) => code == null).length;
    if (dead.length) await Promise.all(dead.map((doc) => doc.ref.delete()));
  }
  return reached;
}
