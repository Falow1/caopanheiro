// Operational authorization and commercial entitlement are independent.
export const companyReleased = (tenant) => !!tenant && ['ACTIVE', 'TRIAL'].includes(tenant.status);
// TRIAL on a company is read-only compatibility with older deliveries.
// In the manager subscription model, a dated cycle (trial or paid) stays
// valid after its date: the E2 phases below decide what is still open.
export function subscriptionValid(subscription, now = Date.now()) {
  return !!subscription && (subscription.status === 'ACTIVE'
    || (subscription.status === 'TRIAL' && typeof subscription.renewsAt?.toMillis === 'function'
      && (!!subscription.accountId || subscription.renewsAt.toMillis() > now)));
}

// Manager subscription model (A1). A petshop created by the SaaS waits for its
// principal manager; a petshop beyond the free plan waits for a paid plan.
export const AWAITING_MANAGER = 'AWAITING_MANAGER';
export const AWAITING_PAID_PLAN = 'AWAITING_PAID_PLAN';
export const TUTOR_APP_CLOSED = 'Este petshop não está recebendo agendamentos pelo app no momento. Fale com o petshop.';
const fields = (doc) => doc && typeof doc.data === 'function' ? doc.data() ?? {} : doc ?? {};

/// Feature of a petshop read from its subscription mirror. A legacy petshop
/// (no entitlements recorded) keeps everything it had.
export function tenantFeature(subscription, key) {
  const value = fields(subscription);
  if (value.pendingReason === AWAITING_PAID_PLAN) return false;
  return value.entitlements?.[key] !== false;
}

/// A petshop the tutor may still read, without commands (A1-u): released by
/// the platform, in the manager subscription model, and without the tutor app.
export function tutorReadOnly(tenant, subscription) {
  const company = fields(tenant), value = fields(subscription);
  return companyReleased(company) && !!value.accountId && (!tenant?.id || value.tenantId === tenant.id)
    && !tenantFeature(value, 'tutorApp');
}

// Expired plan (E2). Only the manager subscription model has these phases; a
// legacy petshop keeps its subscription per petshop, unchanged.
export const WARNING_DAYS = 7;
export const GRACE_DAYS = 7;
const DAY_MS = 86400000;
export const BILLING_OK = 'OK';
export const BILLING_WARNING = 'WARNING';
export const BILLING_GRACE = 'GRACE';
export const BOOKINGS_PAUSED = 'BOOKINGS_PAUSED';
export const BILLING_BLOCKED = 'BLOCKED';
export const ACCESS_PAUSED = 'O acesso a este petshop está pausado no momento. Fale com o gestor do petshop.';
export const TEAM_BOOKINGS_PAUSED = 'Novos agendamentos e remarcações estão pausados neste petshop. Fale com o gestor do petshop.';

/// A covered petshop of a manager subscription with a dated cycle: the trial
/// or a paid plan. The free plan has no date and never expires.
export function datedCycle(subscription) {
  const value = fields(subscription);
  return !!value.accountId && value.pendingReason !== AWAITING_PAID_PLAN && ['TRIAL', 'ACTIVE'].includes(value.status)
    && typeof value.renewsAt?.toMillis === 'function';
}

/// Where the cycle stands by its dates alone: OK, WARNING (7 days or less
/// before the date), GRACE (7 more normal days) or PAST_DEADLINE, when the
/// appointments already booked decide between the pause and the block.
export function cycleClock(subscription, now = Date.now()) {
  const renewsAtMs = fields(subscription).renewsAt.toMillis();
  const deadlineMs = renewsAtMs + GRACE_DAYS * DAY_MS;
  const phase = now < renewsAtMs - WARNING_DAYS * DAY_MS ? BILLING_OK : now < renewsAtMs ? BILLING_WARNING
    : now < deadlineMs ? BILLING_GRACE : 'PAST_DEADLINE';
  return { renewsAtMs, deadlineMs, phase };
}

/// Principal manager of a petshop: the only one who renews and exports and
/// who, while the access is paused, still opens Support and the plan.
export function principalMember(member) {
  const value = fields(member);
  return value.active === true && Array.isArray(value.roles) && value.roles.includes('MANAGER') && value.managementDelegated !== true;
}
export const companySuspended = (tenant) => fields(tenant).status === 'SUSPENDED';
