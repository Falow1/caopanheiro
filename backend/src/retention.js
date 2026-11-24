import { Timestamp } from 'firebase-admin/firestore';

// purgeAt marks when a temporary document may be deleted by the Firestore
// TTL policy of its collection. It is separate from business expiry fields
// (expiresAt), which decide whether an invitation, code or quote is still
// valid. The emulator never deletes by TTL; deletion exists only on a real
// project after the policy is enabled. Documents without purgeAt are kept.
const DAY = 86400000;
export const retention = {
  receipt: 30 * DAY,        // command receipts: protection against repeats
  quote: DAY,               // transport quotes: valid for 15 minutes
  outbox: 7 * DAY,          // local message outboxes (no real delivery)
  limit: 2 * DAY,           // login/code limiters: reset after 24 hours
  mapCache: 30 * DAY,       // address search cache
  afterExpiry: 30 * DAY,    // tutor invitations, after their own expiry
  afterSession: 2 * DAY,    // SaaS administrative sessions, after expiry
};

export const purgeAt = (afterMs, fromMs = Date.now()) => Timestamp.fromMillis(fromMs + afterMs);
