// Expired plan of a petshop in the manager subscription model (E2). Nothing is
// stored: the phase comes from the subscription mirror and, after the
// deadline, from the appointments and transports already booked, so renewing
// opens the petshop again at once and no daily routine is needed for it.
import { Timestamp } from 'firebase-admin/firestore';
import { defaultTimeZone, stateTimeZone, zonedInstant } from './calendar.js';
import { BILLING_BLOCKED, BILLING_OK, BOOKINGS_PAUSED, cycleClock, datedCycle } from './access_policy.js';

const DAY_MS = 86400000;
// Same lists as scheduling and transport operations; kept here to avoid an
// import cycle with runtime.js.
const openTransportStatuses = ['ASSIGNED', 'GOING_TO_ORIGIN', 'PET_COLLECTED', 'IN_TRANSIT'];
export const MAX_BOOKED_READ = 500;
const read = (doc) => doc && typeof doc.data === 'function' ? doc.data() ?? {} : doc ?? {};
const iso = (ms) => ms == null ? null : new Date(ms).toISOString();

/// Civil day of an instant in a zone, as a day count since 1970-01-01.
export function dayIndex(ms, zone = defaultTimeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(ms));
  return Math.round(Date.parse(`${parts}T00:00:00Z`) / DAY_MS);
}
const dayText = (index) => new Date(index * DAY_MS).toISOString().slice(0, 10);

/// Pure rule of the block (E2, confirmed by the user): after the deadline,
/// new bookings stop; the operation blocks on the day after the latest
/// appointment not cancelled (or the day after the deadline, without one), in
/// the petshop zone, and only when no transport is open.
export function blockDecision({ deadlineMs, startsAtMs = [], openTransport = false, zone = defaultTimeZone, now = Date.now(), complete = true }) {
  const lastDay = Math.max(dayIndex(deadlineMs, zone), ...startsAtMs.map((ms) => dayIndex(ms, zone)));
  const blockFromMs = zonedInstant(dayText(lastDay + 1), 0, zone);
  const blocked = complete && !openTransport && dayIndex(now, zone) > lastDay;
  return { phase: blocked ? BILLING_BLOCKED : BOOKINGS_PAUSED, blockFromMs, openTransport };
}

/// Phase of a petshop: OK, WARNING, GRACE, BOOKINGS_PAUSED or BLOCKED, with
/// the dates the apps show. [reader] is a transaction or the database.
export async function tenantPhase(reader, db, tenant, subscription, now = Date.now()) {
  const value = read(subscription);
  if (!datedCycle(value)) return { phase: BILLING_OK };
  const clock = cycleClock(value, now);
  const dates = { renewsAt: iso(clock.renewsAtMs), deadlineAt: iso(clock.deadlineMs) };
  if (clock.phase !== 'PAST_DEADLINE') return { phase: clock.phase, ...dates };
  const tenantId = tenant.id ?? value.tenantId;
  const get = (query) => reader === db ? query.get() : reader.get(query);
  const appointments = await get(db.collection(`tenants/${tenantId}/appointments`)
    .where('startsAt', '>=', Timestamp.fromMillis(clock.deadlineMs)).limit(MAX_BOOKED_READ + 1));
  const transports = await get(db.collection(`tenants/${tenantId}/transports`).where('status', 'in', openTransportStatuses).limit(1));
  const startsAtMs = appointments.docs.filter((doc) => doc.get('status') !== 'CANCELLED')
    .map((doc) => doc.get('startsAt')?.toMillis?.()).filter((ms) => Number.isFinite(ms));
  const zone = stateTimeZone(read(tenant).state) ?? defaultTimeZone;
  // More bookings than one read covers: the petshop stays paused, never blocked by a partial view.
  const decision = blockDecision({ deadlineMs: clock.deadlineMs, startsAtMs, openTransport: !transports.empty, zone, now,
    complete: appointments.size <= MAX_BOOKED_READ });
  return { phase: decision.phase, ...dates, blockFrom: iso(decision.blockFromMs), openTransport: decision.openTransport };
}

/// The view of a phase sent to the apps; [owner] is the principal manager
/// who holds the subscription. The tutor never receives it.
export function phaseView(phase, owner) {
  if (phase.phase === BILLING_OK) return null;
  return { phase: phase.phase, renewsAt: phase.renewsAt ?? null, deadlineAt: phase.deadlineAt ?? null,
    blockFrom: phase.blockFrom ?? null, owner: owner === true };
}
