import { purgeAt, retention } from './retention.js';

// Outgoing e-mail of the SaaS, one function per box. Nothing is sent: each
// message stays in its box, read by the project owner in the emulator or, in
// staging, in the Firebase console. A real mail provider replaces the body of
// these functions before production; the callers stay as they are. The Equipe
// invitation and recovery e-mails are sent by Auth itself (sendPasswordEmail
// in password_check.js); old records of teamLoginEmailOutbox only expire.

/// Manager invitation from the SaaS, written in the invitation transaction.
export function queueManagerInvitation(tx, db, id, message) {
  tx.set(db.doc(`managerInvitationOutbox/${id}`), { ...message, purgeAt: purgeAt(retention.outbox) });
}

/// Access code of the SaaS administrator.
export function queuePlatformEmail(db, id, message, now = Date.now()) {
  return db.doc(`platformEmailOutbox/${id}`).create({ ...message, purgeAt: purgeAt(retention.outbox, now) });
}
