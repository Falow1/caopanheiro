// Subscription of the principal manager (A1). The account under
// billingAccounts/{ownerUid} is the source of truth; each petshop keeps a
// mirror in subscriptions/{tenantId} and tenants/{tenantId}.planId, so the
// checks that already read the petshop plan keep working unchanged.
// A petshop without a billing account stays in the legacy model: one
// subscription per petshop, administered by the SaaS.
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { defaultTimeZone, stateTimeZone, zonedInstant } from './calendar.js';
import { AWAITING_MANAGER, AWAITING_PAID_PLAN, GRACE_DAYS, TUTOR_APP_CLOSED, tenantFeature, tutorReadOnly } from './access_policy.js';

export { AWAITING_MANAGER, AWAITING_PAID_PLAN, GRACE_DAYS, TUTOR_APP_CLOSED, tenantFeature, tutorReadOnly };

export const CYCLE_DAYS = 30;
export const TRIAL_DAYS = 30;
export const WITHDRAWAL_DAYS = 7;
export const DAY_MS = 86400000;
export const FREE_PLAN_ID = 'gratis';
export const TRIAL_PLAN_ID = 'completo';
const featureKeys = ['tutorApp', 'transport', 'onlinePayment'];

const millis = (value) => typeof value?.toMillis === 'function' ? value.toMillis()
  : value instanceof Date ? value.getTime() : typeof value === 'number' ? value : null;
const read = (doc) => doc && typeof doc.data === 'function' ? doc.data() ?? {} : doc ?? {};

/// Civil day of an instant in a zone, as a day count since 1970-01-01.
export function civilDayIndex(ms, zone = defaultTimeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(ms));
  return Math.round(Date.parse(`${parts}T00:00:00Z`) / DAY_MS);
}

/// Whole days left in the cycle, counted from the day after the change up to
/// the renewal day, in the petshop zone (A1-l). Between 0 and CYCLE_DAYS.
export function remainingDays(nowMs, renewsAtMs, zone = defaultTimeZone) {
  if (renewsAtMs == null || renewsAtMs <= nowMs) return 0;
  return Math.max(0, Math.min(CYCLE_DAYS, civilDayIndex(renewsAtMs, zone) - civilDayIndex(nowMs, zone)));
}

/// Proportional value of a monthly difference, rounded in favour of the
/// customer (A1-m): a charge rounds down, a refund rounds up.
export function prorate(monthlyCents, days, direction) {
  const exact = Math.abs(monthlyCents) * days / CYCLE_DAYS;
  return direction === 'REFUND' ? Math.ceil(exact - 1e-9) : Math.floor(exact + 1e-9);
}

export function planFeatures(plan) {
  const value = read(plan).entitlements ?? {};
  return Object.fromEntries(featureKeys.map((key) => [key, value[key] !== false]));
}
export const isFreePlan = (plan, planId) => read(plan).free === true || planId === FREE_PLAN_ID;

/// Monthly value of a cycle: plan price plus the extra petshops (A1-c).
export function cycleCents(plan, tenantCount) {
  const value = read(plan);
  if (value.free === true) return 0;
  const extra = Number.isSafeInteger(value.extraTenantPriceCents) ? value.extraTenantPriceCents : 0;
  return (value.monthlyPriceCents ?? 0) + Math.max(0, tenantCount - 1) * extra;
}

export function accountZone(account) {
  return read(account).timeZone ?? defaultTimeZone;
}
export function zoneOfTenant(tenant) {
  return stateTimeZone(read(tenant).state) ?? defaultTimeZone;
}

/// Situation of the account seen by the apps. A paid cycle past its renewal
/// date is PAST_DUE (E2): it follows the grace and block rule until renewed.
export function accountState(account, now = Date.now()) {
  const value = read(account);
  if (!value.planId) return 'NONE';
  if (value.status === 'TRIAL') return millis(value.renewsAt) > now ? 'TRIAL' : 'TRIAL_ENDED';
  if (value.status === 'ACTIVE') {
    if (value.free === true) return 'FREE';
    const renewsAt = millis(value.renewsAt);
    return renewsAt != null && renewsAt <= now ? 'PAST_DUE' : 'ACTIVE';
  }
  return value.status ?? 'NONE';
}

/// Payments inside the apps (P2/P3) are not connected yet: the screens show
/// Pix, card and boleto as coming soon. This single key turns them on when the
/// payment provider exists; until then nothing is charged in the app.
export const ONLINE_PAYMENTS = Object.freeze({ enabled: false, methods: Object.freeze(['PIX', 'CARD', 'BOLETO']) });
export const onlinePaymentsView = () => ({ enabled: ONLINE_PAYMENTS.enabled, methods: [...ONLINE_PAYMENTS.methods] });

/// Mirror written to subscriptions/{tenantId} for a petshop of the account.
export function tenantMirror(account, plan, tenantId) {
  const value = read(account);
  const covered = (value.tenantIds ?? []).includes(tenantId);
  return {
    tenantId, planId: value.planId, accountId: value.ownerUid, entitlements: planFeatures(plan),
    status: covered ? value.status : 'PENDING',
    renewsAt: covered ? value.renewsAt ?? null : null,
    pendingReason: covered ? FieldValue.delete() : AWAITING_PAID_PLAN,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

/// Writes the mirrors of every petshop of the account (call after all reads).
export function writeMirrors(tx, db, account, plan, uid) {
  const value = read(account);
  for (const tenantId of [...new Set([...(value.tenantIds ?? []), ...(value.waitingTenantIds ?? [])])]) {
    tx.set(db.doc(`subscriptions/${tenantId}`), tenantMirror(value, plan, tenantId), { merge: true });
    tx.update(db.doc(`tenants/${tenantId}`), { planId: value.planId, updatedAt: FieldValue.serverTimestamp(), updatedBy: uid });
  }
}

/// Account for the principal manager when they complete the activation of a
/// petshop that was waiting for them (A1-p, A1-q). Returns the new account and
/// an optional charge for an extra petshop on a paid plan.
export function joinAccount({ account, uid, tenantId, tenant, trialPlan, accountPlan, now = Date.now() }) {
  const current = read(account);
  if (!current.planId) {
    const renewsAt = Timestamp.fromMillis(now + TRIAL_DAYS * DAY_MS);
    return { account: { ownerUid: uid, planId: trialPlan.id, free: false, status: 'TRIAL', renewsAt, trialStartedAt: Timestamp.fromMillis(now),
      tenantIds: [tenantId], waitingTenantIds: [], timeZone: zoneOfTenant(tenant), cancelAtCycleEnd: null, version: 1 }, plan: trialPlan, charge: null };
  }
  const tenantIds = [...new Set([...(current.tenantIds ?? []), tenantId])];
  const waiting = (current.waitingTenantIds ?? []).filter((id) => id !== tenantId);
  const state = accountState(current, now);
  if (state === 'TRIAL') return { account: { ...current, tenantIds, waitingTenantIds: waiting }, plan: accountPlan, charge: null };
  if (state === 'ACTIVE') {
    const days = remainingDays(now, millis(current.renewsAt), accountZone(current));
    const monthly = read(accountPlan).extraTenantPriceCents ?? 0;
    const amountCents = prorate(monthly, days, 'CHARGE');
    return { account: { ...current, tenantIds, waitingTenantIds: waiting }, plan: accountPlan,
      charge: amountCents > 0 ? { reason: 'EXTRA_TENANT', amountCents, days, tenantIds: [tenantId] } : null };
  }
  // Free plan, ended trial or cancelled: the new petshop waits for a paid plan.
  return { account: { ...current, waitingTenantIds: [...new Set([...waiting, tenantId])] }, plan: accountPlan, charge: null };
}

/// Value of moving the account to another plan (A1-g, A1-h, A1-r).
export function changeQuote({ account, fromPlan, toPlan, now = Date.now() }) {
  const current = read(account);
  const tenants = [...new Set([...(current.tenantIds ?? []), ...(current.waitingTenantIds ?? [])])].length || 1;
  const next = cycleCents(toPlan, tenants);
  const state = accountState(current, now);
  if (state !== 'ACTIVE') {
    // From the trial or the free plan, a paid cycle starts now, in full.
    return { kind: 'START', direction: 'CHARGE', days: CYCLE_DAYS, amountCents: next, nextCycleCents: next };
  }
  const days = remainingDays(now, millis(current.renewsAt), accountZone(current));
  const diff = next - cycleCents(fromPlan, (current.tenantIds ?? []).length || 1);
  const direction = diff >= 0 ? 'CHARGE' : 'REFUND';
  return { kind: diff >= 0 ? 'UPGRADE' : 'DOWNGRADE', direction, days, amountCents: prorate(diff, days, direction), nextCycleCents: next };
}

/// Refund of a cancellation "now" (A1-j): the remaining days of the cycle, or
/// the whole first payment within the withdrawal period.
export function cancelQuote({ account, plan, now = Date.now() }) {
  const current = read(account);
  const state = accountState(current, now);
  if (state !== 'ACTIVE') return { days: 0, amountCents: 0, withdrawal: false };
  const paid = cycleCents(plan, (current.tenantIds ?? []).length || 1);
  const firstPaidAt = millis(current.firstPaidAt);
  if (firstPaidAt != null && now - firstPaidAt < WITHDRAWAL_DAYS * DAY_MS && millis(current.cycleStartedAt) === firstPaidAt) {
    return { days: CYCLE_DAYS, amountCents: paid, withdrawal: true };
  }
  const days = remainingDays(now, millis(current.renewsAt), accountZone(current));
  return { days, amountCents: prorate(paid, days, 'REFUND'), withdrawal: false };
}

/// The account after moving to the free plan, keeping one petshop (A1-k, A1-t).
export function freeAccount(account, freePlan, keepTenantId) {
  const current = read(account);
  const all = [...new Set([...(current.tenantIds ?? []), ...(current.waitingTenantIds ?? [])])];
  return { ...current, planId: freePlan.id, free: true, status: 'ACTIVE', renewsAt: null, cycleStartedAt: null,
    tenantIds: [keepTenantId], waitingTenantIds: all.filter((id) => id !== keepTenantId), cancelAtCycleEnd: null };
}

/// The account after a paid plan is confirmed by the platform.
export function paidAccount(account, plan, now = Date.now()) {
  const current = read(account);
  const state = accountState(current, now);
  const all = [...new Set([...(current.tenantIds ?? []), ...(current.waitingTenantIds ?? [])])];
  if (state === 'ACTIVE') return { ...current, planId: plan.id, free: false };
  const start = Timestamp.fromMillis(now);
  return { ...current, planId: plan.id, free: false, status: 'ACTIVE', cycleStartedAt: start,
    renewsAt: Timestamp.fromMillis(now + CYCLE_DAYS * DAY_MS), firstPaidAt: current.firstPaidAt ?? start,
    tenantIds: all, waitingTenantIds: [], cancelAtCycleEnd: null };
}

/// Refund of taking one extra petshop out of the paid cycle and charge of
/// bringing one back, for the remaining days (A1-i). Null outside a paid cycle.
export function extraTenantQuote({ account, plan, now = Date.now() }) {
  const current = read(account);
  if (accountState(current, now) !== 'ACTIVE') return null;
  const monthly = read(plan).extraTenantPriceCents;
  const monthlyCents = Number.isSafeInteger(monthly) ? monthly : 0;
  const days = remainingDays(now, millis(current.renewsAt), accountZone(current));
  return { days, monthlyCents, removeCents: prorate(monthlyCents, days, 'REFUND'), addCents: prorate(monthlyCents, days, 'CHARGE') };
}

/// Why a petshop cannot leave or come back to the paid cycle now, or null.
/// [pending]: requests of the account still waiting for the platform.
export function extraTenantProblem({ account, tenantId, action, pending = [], now = Date.now() }) {
  const current = read(account);
  const covered = current.tenantIds ?? [], waiting = current.waitingTenantIds ?? [];
  if (![...covered, ...waiting].includes(tenantId)) return 'Escolha um dos seus petshops.';
  if (accountState(current, now) !== 'ACTIVE') return 'Petshops entram e saem da assinatura só com um plano pago ativo.';
  if (current.cancelAtCycleEnd) return 'O cancelamento já está marcado para o fim do ciclo.';
  if (pending.some((item) => item.kind === 'PLAN_CHANGE')) return 'Há um pedido de troca de plano aguardando a plataforma.';
  if (action === 'ADD') return waiting.includes(tenantId) ? null : 'Este petshop já está na assinatura.';
  if (!covered.includes(tenantId)) return 'Este petshop já está fora da assinatura.';
  if (covered.length < 2) return 'O único petshop da assinatura não sai. Para isso, cancele a assinatura.';
  if (pending.some((item) => item.kind === 'CHARGE' && (item.tenantIds ?? []).includes(tenantId))) return 'O pagamento deste petshop ainda aguarda a plataforma.';
  return null;
}

/// The account with the petshop out of the paid cycle (it waits for a paid
/// plan, with its data kept) or back in it.
export function movedTenant(account, tenantId, action) {
  const current = read(account);
  const covered = (current.tenantIds ?? []).filter((id) => id !== tenantId);
  const waiting = (current.waitingTenantIds ?? []).filter((id) => id !== tenantId);
  return action === 'ADD' ? { ...current, tenantIds: [...covered, tenantId], waitingTenantIds: waiting }
    : { ...current, tenantIds: covered, waitingTenantIds: [...waiting, tenantId] };
}

/// Value of renewing a paid cycle (E2, path A): the monthly value of the
/// plan and the covered petshops, for 30 more days. Null outside a paid plan.
export function renewalQuote({ account, plan, now = Date.now() }) {
  const current = read(account);
  if (!['ACTIVE', 'PAST_DUE'].includes(accountState(current, now))) return null;
  return { amountCents: cycleCents(plan, (current.tenantIds ?? []).length || 1), days: CYCLE_DAYS };
}

/// The account after the platform confirms a renewal. Paid within the grace
/// days, the new cycle follows the old date; later, it starts on the day.
export function renewedAccount(account, now = Date.now()) {
  const current = read(account);
  const renewsAt = millis(current.renewsAt);
  const base = renewsAt != null && now < renewsAt + GRACE_DAYS * DAY_MS ? renewsAt : now;
  return { ...current, status: 'ACTIVE', free: false, cycleStartedAt: Timestamp.fromMillis(base),
    renewsAt: Timestamp.fromMillis(base + CYCLE_DAYS * DAY_MS), lastRenewedAt: Timestamp.fromMillis(now) };
}

/// End of a civil day in the account zone, for "Renovar até" in the SaaS.
export function endOfDay(day, zone = defaultTimeZone) {
  const next = new Date(Date.parse(`${day}T00:00:00Z`) + DAY_MS).toISOString().slice(0, 10);
  // Midnight of the next day in the zone, or 01:00 where midnight is skipped.
  return zonedInstant(next, 0, zone) ?? zonedInstant(next, 60, zone);
}

/// The account renewed by the platform up to a chosen date ("Renovar até"):
/// a paid plan stays paid, the trial keeps being a trial.
export function extendedAccount(account, untilMs) {
  const current = read(account);
  return { ...current, renewsAt: Timestamp.fromMillis(untilMs), lastRenewedAt: Timestamp.fromMillis(Date.now()) };
}
