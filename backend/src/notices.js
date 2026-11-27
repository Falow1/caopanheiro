import { onCall } from './callable.js';
import { Timestamp } from 'firebase-admin/firestore';
import { actor, identifier, invalid, localBackend, object, options, teamAccess } from './runtime.js';

// In-app notices: read when the app opens or refreshes. The server of the
// Fly.io also sends each new notice as a push to the Equipe app of the people
// of its channel (server/push_delivery.js); no e-mail or SMS.
const RETENTION_MS = 60 * 86400000;
const personalRoles = ['TUTOR', 'PROFESSIONAL', 'DRIVER'];
const noticeRoles = ['TEAM', ...personalRoles];
const accessRoles = { TEAM: ['MANAGER', 'ATTENDANT'], TUTOR: ['TUTOR'], PROFESSIONAL: ['PROFESSIONAL'], DRIVER: ['DRIVER'] };
const channelsFor = (role, uid) => role === 'TEAM' ? ['TEAM', `TEAM:${uid}`] : [`${role}:${uid}`];

/// "2026-11-09T14:30:00" -> "09/11 às 14:30"; falls back to the raw text.
export function noticeDate(local) {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(local ?? '');
  return match ? `${match[3]}/${match[2]} às ${match[4]}:${match[5]}` : '';
}
export const petNames = (items) => (items ?? []).map((item) => item.pet?.name ?? item.name).filter(Boolean).join(', ');

/// Queues notices in the write phase of a transaction. A notice addressed to
/// the person who performed the action is skipped: they already know.
export function notify(tx, db, tenantId, actorUid, rows) {
  const now = Date.now();
  for (const row of rows) {
    if (!row) continue;
    const personal = row.role !== 'TEAM' || row.targetUid != null;
    if (personal && (!row.targetUid || row.targetUid === actorUid)) continue;
    const channel = row.role === 'TEAM' ? (row.targetUid ? `TEAM:${row.targetUid}` : 'TEAM') : `${row.role}:${row.targetUid}`;
    tx.create(db.collection(`tenants/${tenantId}/notices`).doc(), {
      channel, type: row.type, title: String(row.title).slice(0, 120), text: String(row.text ?? '').slice(0, 500),
      appointmentId: row.appointmentId ?? null, transportId: row.transportId ?? null, supportRequestId: row.supportRequestId ?? null,
      actorUid: actorUid ?? null, createdAt: new Date(now).toISOString(), createdAtMs: now,
      expiresAt: Timestamp.fromMillis(now + RETENTION_MS),
    });
  }
}

const markerRef = (db, tenantId, uid) => db.doc(`tenants/${tenantId}/noticeMarkers/${uid}`);
function roleValue(value) { if (!noticeRoles.includes(value)) invalid('Área de avisos inválida.'); return value; }

export const getNotices = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId', 'role'], 'Consulta');
  const tenantId = identifier(request.data.tenantId, 'Empresa'); const role = roleValue(request.data.role);
  return db.runTransaction(async (tx) => {
    await teamAccess(tx, db, tenantId, uid, accessRoles[role], { tutorRead: role === 'TUTOR' });
    const page = await tx.get(db.collection(`tenants/${tenantId}/notices`).where('channel', 'in', channelsFor(role, uid)).orderBy('createdAtMs', 'desc').limit(30));
    const marker = await tx.get(markerRef(db, tenantId, uid));
    const seenAtMs = marker.get(role) ?? 0; const now = Date.now();
    const items = page.docs.filter((doc) => (doc.get('expiresAt')?.toMillis?.() ?? Infinity) > now).map((doc) => ({
      id: doc.id, type: doc.get('type'), title: doc.get('title'), text: doc.get('text'),
      appointmentId: doc.get('appointmentId') ?? null, transportId: doc.get('transportId') ?? null,
      supportRequestId: doc.get('supportRequestId') ?? null, createdAt: doc.get('createdAt'), unread: doc.get('createdAtMs') > seenAtMs,
    }));
    return { items, unread: items.filter((item) => item.unread).length };
  });
});

export const markNoticesSeen = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId', 'role'], 'Pedido');
  const tenantId = identifier(request.data.tenantId, 'Empresa'); const role = roleValue(request.data.role);
  await db.runTransaction(async (tx) => {
    await teamAccess(tx, db, tenantId, uid, accessRoles[role], { tutorRead: role === 'TUTOR' });
    tx.set(markerRef(db, tenantId, uid), { [role]: Date.now() }, { merge: true });
  });
  return { seen: true };
});
