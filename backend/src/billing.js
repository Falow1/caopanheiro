// Subscription of the principal manager (A1): overview and requests in the
// Equipe app, and the pending items the SaaS confirms. Without payments in the
// app yet (P2), money moves outside it: the platform confirms each charge or
// refund here before the change applies.
import { HttpsError } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { onCall } from './callable.js';
import { actor, digest, identifier, invalid, localBackend, object, options, text } from './runtime.js';
import { adminAccess, platformCommand } from './saas.js';
import { requireEmailSession } from './saas_email.js';
import { staffSeatOccupied } from './manager_activation.js';
import {
  DAY_MS, FREE_PLAN_ID, GRACE_DAYS, accountState, accountZone, cancelQuote, changeQuote, cycleCents, endOfDay, extendedAccount, extraTenantProblem,
  extraTenantQuote, freeAccount, isFreePlan, movedTenant, onlinePaymentsView, paidAccount, planFeatures, renewalQuote, renewedAccount, writeMirrors,
} from './billing_policy.js';
import { tenantPhase } from './billing_phase.js';
import { dayValue } from './calendar.js';
import { purgeAt, retention } from './retention.js';
import { staffMembers } from './staff_members.js';

const iso = (value) => value?.toDate?.().toISOString() ?? null;
const requestKinds = ['PLAN_CHANGE', 'CHARGE', 'REFUND', 'RENEWAL'];
const millis = (value) => value?.toMillis?.() ?? null;
const MAX_RENEWAL_DAYS = 400;
const MAX_PLANS = 20;

function planView(doc) {
  return { id: doc.id, name: doc.get('name') ?? doc.id, description: doc.get('description') ?? '',
    monthlyPriceCents: doc.get('monthlyPriceCents') ?? 0, extraTenantPriceCents: doc.get('extraTenantPriceCents') ?? 0,
    maxUsers: doc.get('maxUsers') ?? null, maxProfessionals: doc.get('maxProfessionals') ?? null,
    maxTenants: doc.get('maxTenants') ?? null, free: isFreePlan(doc, doc.id), features: planFeatures(doc),
    featureNames: doc.get('features') ?? [] };
}

// Only the team is read: tutors linked to customer records occupy no seat.
// A plan check refuses a team above the query limit; a report accepts it capped.
async function tenantUsage(reader, db, tenantId, { allowCapped = false } = {}) {
  const read = (query) => reader === db ? query.get() : reader.get(query);
  const [members, professionals] = await Promise.all([
    staffMembers(reader, db, tenantId, { allowCapped }),
    read(db.collection(`tenants/${tenantId}/professionals`).where('active', '==', true).limit(101)),
  ]);
  return { users: members.docs.filter((doc) => staffSeatOccupied(doc.data())).length, professionals: professionals.size };
}

/// Why a plan cannot take the petshops as they are today (A1-h, P1-b).
function limitProblem(plan, usages) {
  const over = usages.filter((usage) => (plan.maxUsers != null && usage.users > plan.maxUsers)
    || (plan.maxProfessionals != null && usage.professionals > plan.maxProfessionals));
  if (!over.length) return null;
  return `Desative pessoas ou profissionais até ficar dentro do limite de ${plan.maxUsers} por petshop.`;
}

async function ownerAccount(reader, db, uid) {
  const ref = db.doc(`billingAccounts/${uid}`);
  const account = reader === db ? await ref.get() : await reader.get(ref);
  if (!account.exists) throw new HttpsError('failed-precondition', 'A assinatura é do gestor principal.');
  return account;
}

function requestView(doc) {
  const value = doc.data();
  return { id: doc.id, kind: value.kind, status: value.status, accountId: value.accountId, ownerName: value.ownerName ?? '',
    fromPlanId: value.fromPlanId ?? null, fromPlanName: value.fromPlanName ?? null, toPlanId: value.toPlanId ?? null,
    toPlanName: value.toPlanName ?? null, direction: value.direction ?? null, amountCents: value.amountCents ?? 0,
    days: value.days ?? null, reason: value.reason ?? null, tenantNames: value.tenantNames ?? [],
    decisionReason: value.decisionReason ?? null, createdAt: iso(value.createdAt), decidedAt: iso(value.decidedAt) };
}

export const getBillingOverview = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  // The Equipe app sends the selected petshop; the account is the caller's own.
  object(request.data, ['tenantId'], 'Consulta');
  const account = await db.doc(`billingAccounts/${uid}`).get();
  if (!account.exists) return { account: null };
  const now = Date.now(); const value = account.data();
  const tenantIds = [...new Set([...(value.tenantIds ?? []), ...(value.waitingTenantIds ?? [])])];
  const [planDocs, tenants, mirrors, pending] = await Promise.all([
    db.collection('plans').where('active', '==', true).limit(MAX_PLANS).get(),
    tenantIds.length ? db.getAll(...tenantIds.map((id) => db.doc(`tenants/${id}`))) : [],
    tenantIds.length ? db.getAll(...tenantIds.map((id) => db.doc(`subscriptions/${id}`))) : [],
    db.collection('billingRequests').where('accountId', '==', uid).where('status', '==', 'PENDING').limit(20).get(),
  ]);
  const currentPlan = await db.doc(`plans/${value.planId}`).get();
  const waitingItems = pending.docs.map((doc) => doc.data());
  const usages = await Promise.all(tenantIds.map((id) => tenantUsage(db, db, id, { allowCapped: true })));
  // Phase of each covered petshop after the date (E2): paused or blocked.
  const phases = await Promise.all(tenantIds.map((id, index) => (value.tenantIds ?? []).includes(id) && tenants[index]?.exists
    ? tenantPhase(db, db, tenants[index], mirrors[index], now) : null));
  const renewsAtMs = millis(value.renewsAt);
  const coveredUsages = usages.filter((_, index) => (value.tenantIds ?? []).includes(tenantIds[index]));
  const plans = planDocs.docs.map((doc) => {
    const plan = planView(doc), current = doc.id === value.planId && accountState(value, now) !== 'TRIAL_ENDED';
    if (plan.free) return { ...plan, current, quote: null, blockedReason: null };
    const problem = limitProblem(plan, coveredUsages.length ? coveredUsages : usages);
    const quote = current && accountState(value, now) !== 'TRIAL' ? null : changeQuote({ account: value, fromPlan: currentPlan, toPlan: doc, now });
    return { ...plan, current, quote, blockedReason: problem };
  }).sort((a, b) => a.monthlyPriceCents - b.monthlyPriceCents);
  return {
    account: {
      state: accountState(value, now), planId: value.planId, planName: currentPlan.get('name') ?? value.planId,
      renewsAt: iso(value.renewsAt), firstPaidAt: iso(value.firstPaidAt),
      deadlineAt: renewsAtMs != null && ['TRIAL', 'TRIAL_ENDED', 'ACTIVE', 'PAST_DUE'].includes(accountState(value, now))
        ? new Date(renewsAtMs + GRACE_DAYS * DAY_MS).toISOString() : null,
      cycleCents: cycleCents(currentPlan, (value.tenantIds ?? []).length || 1),
      cancelAtCycleEnd: value.cancelAtCycleEnd ? { keepTenantId: value.cancelAtCycleEnd.keepTenantId, at: iso(value.cancelAtCycleEnd.at) } : null,
      tenants: tenantIds.map((id, index) => ({ id, name: tenants[index]?.get?.('tradeName') ?? tenants[index]?.get?.('name') ?? id,
        covered: (value.tenantIds ?? []).includes(id), usage: usages[index],
        maxUsers: currentPlan.get('maxUsers') ?? null, maxProfessionals: currentPlan.get('maxProfessionals') ?? null,
        action: tenantAction(value, id, waitingItems, now), phase: phases[index]?.phase ?? null })),
    },
    plans, pendingRequests: pending.docs.map(requestView),
    cancelQuote: cancelQuote({ account: value, plan: currentPlan, now }),
    tenantQuote: extraTenantQuote({ account: value, plan: currentPlan, now }),
    renewalQuote: value.cancelAtCycleEnd ? null : renewalQuote({ account: value, plan: currentPlan, now }),
    onlinePayments: onlinePaymentsView(),
  };
});

/// REMOVE, ADD or null: what the manager can do with a petshop of the paid cycle (A1-i).
function tenantAction(account, tenantId, pending, now) {
  const action = (account.tenantIds ?? []).includes(tenantId) ? 'REMOVE' : 'ADD';
  return extraTenantProblem({ account, tenantId, action, pending, now }) ? null : action;
}

/// Receipt of an owner command, so a repeated request returns the same result.
async function ownerReceipt(tx, db, uid, requestId, action, input) {
  const ref = db.doc(`billingReceipts/${digest(JSON.stringify([uid, requestId]))}`);
  const receipt = await tx.get(ref);
  const hash = digest(JSON.stringify([action, input]));
  if (receipt.exists && receipt.get('inputHash') !== hash) throw new HttpsError('already-exists', 'Operação já usada com outros dados.');
  return { ref, receipt, hash };
}

export const requestPlanChange = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId', 'requestId', 'planId'], 'Pedido');
  const requestId = identifier(request.data.requestId, 'Operação', 16); const planId = identifier(request.data.planId, 'Plano');
  return db.runTransaction(async (tx) => {
    const { ref, receipt, hash } = await ownerReceipt(tx, db, uid, requestId, 'requestPlanChange', { planId });
    if (receipt.exists) return { ...receipt.get('result'), replayed: true };
    const account = await ownerAccount(tx, db, uid); const value = account.data(); const now = Date.now();
    const [fromPlan, toPlan, owner] = await tx.getAll(db.doc(`plans/${value.planId}`), db.doc(`plans/${planId}`), db.doc(`users/${uid}`));
    if (!toPlan.exists || toPlan.get('active') !== true) throw new HttpsError('failed-precondition', 'Plano indisponível.');
    if (isFreePlan(toPlan, planId)) throw new HttpsError('failed-precondition', 'Para ir ao Grátis, use Cancelar assinatura.');
    const state = accountState(value, now);
    if (planId === value.planId && state === 'ACTIVE') throw new HttpsError('failed-precondition', 'Este já é o seu plano.');
    if (planId === value.planId && state === 'PAST_DUE') throw new HttpsError('failed-precondition', 'Para continuar neste plano, use Pagar agora.');
    const pending = (await tx.get(db.collection('billingRequests').where('accountId', '==', uid).where('status', '==', 'PENDING').limit(20))).docs;
    if (pending.some((doc) => doc.get('kind') === 'PLAN_CHANGE')) throw new HttpsError('failed-precondition', 'Já existe um pedido de troca aguardando a plataforma.');
    if (pending.some((doc) => doc.get('kind') === 'RENEWAL')) throw new HttpsError('failed-precondition', 'A renovação aguarda a confirmação da plataforma.');
    const tenantIds = [...new Set([...(value.tenantIds ?? []), ...(value.waitingTenantIds ?? [])])];
    const tenants = tenantIds.length ? await tx.getAll(...tenantIds.map((id) => db.doc(`tenants/${id}`))) : [];
    const usages = []; for (const id of tenantIds) usages.push(await tenantUsage(tx, db, id));
    const problem = limitProblem(planView(toPlan), usages);
    if (problem) throw new HttpsError('failed-precondition', problem);
    const quote = changeQuote({ account: value, fromPlan, toPlan, now });
    const requestRef = db.collection('billingRequests').doc();
    tx.create(requestRef, { kind: 'PLAN_CHANGE', status: 'PENDING', accountId: uid, ownerName: owner.get('name') ?? '',
      fromPlanId: value.planId, fromPlanName: fromPlan.get('name') ?? value.planId, toPlanId: planId, toPlanName: toPlan.get('name') ?? planId,
      direction: quote.direction, amountCents: quote.amountCents, days: quote.days, quoteKind: quote.kind, nextCycleCents: quote.nextCycleCents,
      tenantIds, tenantNames: tenants.map((doc) => doc.get('tradeName') ?? doc.id), createdAt: FieldValue.serverTimestamp() });
    const result = { billingRequestId: requestRef.id, direction: quote.direction, amountCents: quote.amountCents, days: quote.days };
    tx.create(ref, { action: 'requestPlanChange', inputHash: hash, result, actorUid: uid, confirmedAt: FieldValue.serverTimestamp(), purgeAt: purgeAt(retention.receipt) });
    return { ...result, replayed: false };
  });
});

export const cancelSubscription = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId', 'requestId', 'mode', 'keepTenantId'], 'Cancelamento');
  const requestId = identifier(request.data.requestId, 'Operação', 16); const keepTenantId = identifier(request.data.keepTenantId, 'Petshop');
  const mode = request.data.mode; if (!['END_OF_CYCLE', 'NOW'].includes(mode)) invalid('Escolha quando cancelar.');
  return db.runTransaction(async (tx) => {
    const { ref, receipt, hash } = await ownerReceipt(tx, db, uid, requestId, 'cancelSubscription', { mode, keepTenantId });
    if (receipt.exists) return { ...receipt.get('result'), replayed: true };
    const account = await ownerAccount(tx, db, uid); const value = account.data(); const now = Date.now();
    const state = accountState(value, now);
    // After the trial, the manager chooses a plan or the free plan (A1-p).
    if (!['TRIAL', 'TRIAL_ENDED', 'ACTIVE', 'PAST_DUE'].includes(state)) throw new HttpsError('failed-precondition', 'Não há assinatura paga ou teste para cancelar.');
    if (![...(value.tenantIds ?? []), ...(value.waitingTenantIds ?? [])].includes(keepTenantId)) throw new HttpsError('failed-precondition', 'Escolha um dos seus petshops.');
    const [plan, freePlan, owner] = await tx.getAll(db.doc(`plans/${value.planId}`), db.doc(`plans/${FREE_PLAN_ID}`), db.doc(`users/${uid}`));
    if (!freePlan.exists || freePlan.get('active') !== true) throw new HttpsError('failed-precondition', 'Plano Grátis indisponível. Fale com o Suporte da plataforma.');
    // A plan change or a renewal waiting for the platform ends with the cancellation.
    const pending = (await tx.get(db.collection('billingRequests').where('accountId', '==', uid).where('status', '==', 'PENDING').limit(20))).docs
      .filter((doc) => ['PLAN_CHANGE', 'RENEWAL'].includes(doc.get('kind')));
    let result;
    if (mode === 'END_OF_CYCLE' && !['TRIAL_ENDED', 'PAST_DUE'].includes(state) && value.renewsAt) {
      tx.update(account.ref, { cancelAtCycleEnd: { keepTenantId, at: value.renewsAt, requestedAt: Timestamp.fromMillis(now) }, updatedAt: FieldValue.serverTimestamp() });
      result = { mode, at: iso(value.renewsAt), refundCents: 0 };
    } else {
      const quote = cancelQuote({ account: value, plan, now });
      const next = freeAccount(value, freePlan, keepTenantId);
      tx.set(account.ref, { ...next, updatedAt: FieldValue.serverTimestamp(), cancelledAt: Timestamp.fromMillis(now) });
      writeMirrors(tx, db, next, freePlan, uid);
      if (quote.amountCents > 0) {
        tx.create(db.collection('billingRequests').doc(), { kind: 'REFUND', status: 'PENDING', accountId: uid, ownerName: owner.get('name') ?? '',
          fromPlanId: value.planId, fromPlanName: plan.get('name') ?? value.planId, direction: 'REFUND', amountCents: quote.amountCents,
          days: quote.days, reason: quote.withdrawal ? 'WITHDRAWAL' : 'CANCEL_NOW', createdAt: FieldValue.serverTimestamp() });
      }
      result = { mode: 'NOW', refundCents: quote.amountCents, withdrawal: quote.withdrawal };
    }
    for (const doc of pending) tx.update(doc.ref, { status: 'CANCELLED', decidedAt: FieldValue.serverTimestamp(), decisionReason: 'Assinatura cancelada pelo gestor.' });
    tx.create(ref, { action: 'cancelSubscription', inputHash: hash, result, actorUid: uid, confirmedAt: FieldValue.serverTimestamp(), purgeAt: purgeAt(retention.receipt) });
    return { ...result, replayed: false };
  });
});

/// An extra petshop leaves the paid cycle, with the refund of the remaining
/// days, or comes back, with the proportional charge (A1-i). The change is
/// immediate; the platform registers the refund or confirms the payment.
export const changeAccountTenant = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId', 'requestId', 'targetTenantId', 'action'], 'Petshop');
  const requestId = identifier(request.data.requestId, 'Operação', 16); const targetTenantId = identifier(request.data.targetTenantId, 'Petshop');
  const action = request.data.action; if (!['REMOVE', 'ADD'].includes(action)) invalid('Escolha tirar ou incluir o petshop.');
  return db.runTransaction(async (tx) => {
    const { ref, receipt, hash } = await ownerReceipt(tx, db, uid, requestId, 'changeAccountTenant', { targetTenantId, action });
    if (receipt.exists) return { ...receipt.get('result'), replayed: true };
    const account = await ownerAccount(tx, db, uid); const value = account.data(); const now = Date.now();
    const pending = await tx.get(db.collection('billingRequests').where('accountId', '==', uid).where('status', '==', 'PENDING').limit(20));
    const problem = extraTenantProblem({ account: value, tenantId: targetTenantId, action, pending: pending.docs.map((doc) => doc.data()), now });
    if (problem) throw new HttpsError('failed-precondition', problem);
    const [plan, owner, tenant] = await tx.getAll(db.doc(`plans/${value.planId}`), db.doc(`users/${uid}`), db.doc(`tenants/${targetTenantId}`));
    if (!plan.exists) throw new HttpsError('failed-precondition', 'Plano indisponível. Fale com o Suporte da plataforma.');
    if (action === 'ADD') {
      const usageProblem = limitProblem(planView(plan), [await tenantUsage(tx, db, targetTenantId)]);
      if (usageProblem) throw new HttpsError('failed-precondition', usageProblem);
    }
    const quote = extraTenantQuote({ account: value, plan, now });
    const next = movedTenant(value, targetTenantId, action);
    tx.set(account.ref, { ...next, updatedAt: FieldValue.serverTimestamp() });
    writeMirrors(tx, db, next, plan, uid);
    const amountCents = action === 'ADD' ? quote.addCents : quote.removeCents;
    if (amountCents > 0) {
      const direction = action === 'ADD' ? 'CHARGE' : 'REFUND';
      tx.create(db.collection('billingRequests').doc(), { kind: direction, status: 'PENDING', accountId: uid, ownerName: owner.get('name') ?? '',
        direction, reason: action === 'ADD' ? 'EXTRA_TENANT' : 'EXTRA_TENANT_REMOVED', amountCents, days: quote.days,
        fromPlanId: value.planId, fromPlanName: plan.get('name') ?? value.planId, toPlanId: value.planId, toPlanName: plan.get('name') ?? value.planId,
        tenantIds: [targetTenantId], tenantNames: [tenant.get('tradeName') ?? tenant.get('name') ?? targetTenantId], createdAt: FieldValue.serverTimestamp() });
    }
    const result = { action, days: quote.days, nextCycleCents: cycleCents(plan, next.tenantIds.length),
      ...(action === 'ADD' ? { chargeCents: amountCents } : { refundCents: amountCents }) };
    tx.create(ref, { action: 'changeAccountTenant', inputHash: hash, result, actorUid: uid, confirmedAt: FieldValue.serverTimestamp(), purgeAt: purgeAt(retention.receipt) });
    return { ...result, replayed: false };
  });
});

/// "Pagar agora" then "Já paguei" (E2, path A): the manager tells the platform
/// that the monthly value was paid outside the app. The SaaS checks the money
/// and confirms; until then the petshops follow the date of the cycle.
export const requestRenewal = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId', 'requestId'], 'Renovação');
  const requestId = identifier(request.data.requestId, 'Operação', 16);
  return db.runTransaction(async (tx) => {
    const { ref, receipt, hash } = await ownerReceipt(tx, db, uid, requestId, 'requestRenewal', {});
    if (receipt.exists) return { ...receipt.get('result'), replayed: true };
    const account = await ownerAccount(tx, db, uid); const value = account.data(); const now = Date.now();
    const [plan, owner] = await tx.getAll(db.doc(`plans/${value.planId}`), db.doc(`users/${uid}`));
    const quote = plan.exists ? renewalQuote({ account: value, plan, now }) : null;
    if (!quote) throw new HttpsError('failed-precondition', 'A renovação é do plano pago. No teste, escolha um plano.');
    if (value.cancelAtCycleEnd) throw new HttpsError('failed-precondition', 'O cancelamento já está marcado para o fim do ciclo.');
    const pending = (await tx.get(db.collection('billingRequests').where('accountId', '==', uid).where('status', '==', 'PENDING').limit(20))).docs;
    if (pending.some((doc) => doc.get('kind') === 'RENEWAL')) throw new HttpsError('failed-precondition', 'A renovação já aguarda a confirmação da plataforma.');
    if (pending.some((doc) => doc.get('kind') === 'PLAN_CHANGE')) throw new HttpsError('failed-precondition', 'Há um pedido de troca de plano aguardando a plataforma.');
    const tenantIds = value.tenantIds ?? [];
    const tenants = tenantIds.length ? await tx.getAll(...tenantIds.map((id) => db.doc(`tenants/${id}`))) : [];
    const requestRef = db.collection('billingRequests').doc();
    tx.create(requestRef, { kind: 'RENEWAL', status: 'PENDING', accountId: uid, ownerName: owner.get('name') ?? '',
      fromPlanId: value.planId, fromPlanName: plan.get('name') ?? value.planId, toPlanId: value.planId, toPlanName: plan.get('name') ?? value.planId,
      direction: 'CHARGE', amountCents: quote.amountCents, days: quote.days, renewsAt: value.renewsAt ?? null,
      tenantIds, tenantNames: tenants.map((doc) => doc.get('tradeName') ?? doc.id), createdAt: FieldValue.serverTimestamp() });
    const result = { billingRequestId: requestRef.id, amountCents: quote.amountCents, days: quote.days };
    tx.create(ref, { action: 'requestRenewal', inputHash: hash, result, actorUid: uid, confirmedAt: FieldValue.serverTimestamp(), purgeAt: purgeAt(retention.receipt) });
    return { ...result, replayed: false };
  });
});

/// "Renovar até" in the SaaS (E2): for exceptions, such as a payment of
/// several months or a courtesy. The cycle goes up to the end of the chosen
/// day, in the zone of the account; the reason stays in the audit.
export const renewSubscriptionUntil = onCall(options, async (request) => {
  object(request.data, ['requestId', 'tenantId', 'until', 'reason'], 'Renovação');
  const tenantId = identifier(request.data.tenantId, 'Petshop');
  const until = dayValue(request.data.until);
  const reason = text(request.data.reason ?? '', 'Motivo', 500, 3);
  return platformCommand(request, 'renewSubscriptionUntil', { tenantId, until, reason }, async ({ tx, db, uid }) => {
    const subscription = await tx.get(db.doc(`subscriptions/${tenantId}`));
    const accountId = subscription.get('accountId');
    if (!accountId) throw new HttpsError('failed-precondition', 'Este petshop usa a assinatura por petshop. Use Assinatura do petshop.');
    const accountRef = db.doc(`billingAccounts/${identifier(accountId, 'Conta')}`);
    const account = await tx.get(accountRef);
    if (!account.exists) throw new HttpsError('failed-precondition', 'Assinatura do gestor indisponível.');
    const value = account.data(), now = Date.now();
    if (!['TRIAL', 'TRIAL_ENDED', 'ACTIVE', 'PAST_DUE'].includes(accountState(value, now))) throw new HttpsError('failed-precondition', 'No Grátis não há data para renovar.');
    const untilMs = endOfDay(until, accountZone(value));
    if (untilMs == null || untilMs <= now) throw new HttpsError('failed-precondition', 'Escolha uma data a partir de hoje.');
    if (untilMs > now + MAX_RENEWAL_DAYS * DAY_MS) throw new HttpsError('failed-precondition', `Escolha uma data em até ${MAX_RENEWAL_DAYS} dias.`);
    const plan = await tx.get(db.doc(`plans/${identifier(value.planId, 'Plano')}`));
    const next = extendedAccount(value, untilMs);
    tx.set(accountRef, { ...next, updatedAt: FieldValue.serverTimestamp() });
    writeMirrors(tx, db, next, plan, uid);
    return { tenantId, accountId: account.id, renewsAt: new Date(untilMs).toISOString() };
  });
});

/// Pending items for the SaaS (A1-s): plan changes to confirm, charges and
/// refunds made outside the app, and support requests waiting for a reply.
export const getBillingRequests = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, [], 'Consulta');
  await adminAccess(db, db, uid); await requireEmailSession(request, db, uid);
  const [pending, support] = await Promise.all([
    db.collection('billingRequests').where('status', '==', 'PENDING').limit(200).get(),
    db.collection('supportRequests').where('status', '==', 'OPEN').limit(201).get(),
  ]);
  const items = pending.docs.map(requestView).sort((a, b) => String(a.createdAt).localeCompare(String(b.createdAt)));
  return { items, counts: { planChanges: items.filter((item) => item.kind === 'PLAN_CHANGE').length,
    renewals: items.filter((item) => item.kind === 'RENEWAL').length,
    charges: items.filter((item) => item.kind === 'CHARGE').length, refunds: items.filter((item) => item.kind === 'REFUND').length,
    supportWaiting: Math.min(support.size, 200), supportCapped: support.size > 200 } };
});

export const decideBillingRequest = onCall(options, async (request) => {
  object(request.data, ['requestId', 'billingRequestId', 'decision', 'reason'], 'Pedido');
  const billingRequestId = identifier(request.data.billingRequestId, 'Pedido');
  const decision = request.data.decision; if (!['APPROVE', 'REJECT'].includes(decision)) invalid('Decisão inválida.');
  const reason = text(request.data.reason ?? '', 'Motivo', 500, decision === 'REJECT' ? 3 : 0);
  return platformCommand(request, 'decideBillingRequest', { billingRequestId, decision, reason }, async ({ tx, db, uid }) => {
    const ref = db.doc(`billingRequests/${billingRequestId}`); const item = await tx.get(ref);
    if (!item.exists || !requestKinds.includes(item.get('kind'))) throw new HttpsError('not-found', 'Pedido indisponível.');
    if (item.get('status') !== 'PENDING') throw new HttpsError('failed-precondition', 'Este pedido já foi decidido.');
    const decided = { decidedAt: FieldValue.serverTimestamp(), decidedBy: uid, decisionReason: reason || null };
    if (decision === 'REJECT') { tx.update(ref, { status: 'REJECTED', ...decided }); return { billingRequestId, status: 'REJECTED' }; }
    if (item.get('kind') === 'RENEWAL') {
      // Renewal confirmed (E2, path A): 30 more days, and the petshops open at once.
      const accountRef = db.doc(`billingAccounts/${identifier(item.get('accountId'), 'Conta')}`);
      const account = await tx.get(accountRef);
      const state = account.exists ? accountState(account.data(), Date.now()) : 'NONE';
      if (!['ACTIVE', 'PAST_DUE'].includes(state)) throw new HttpsError('failed-precondition', 'A assinatura não está mais num plano pago. Recuse o pedido com o motivo.');
      const plan = await tx.get(db.doc(`plans/${identifier(account.get('planId'), 'Plano')}`));
      const next = renewedAccount(account.data(), Date.now());
      tx.set(accountRef, { ...next, updatedAt: FieldValue.serverTimestamp() });
      writeMirrors(tx, db, next, plan, uid);
      tx.update(ref, { status: 'APPROVED', ...decided });
      return { billingRequestId, status: 'APPROVED', renewsAt: next.renewsAt.toDate().toISOString() };
    }
    if (item.get('kind') !== 'PLAN_CHANGE') { tx.update(ref, { status: 'DONE', ...decided }); return { billingRequestId, status: 'DONE' }; }
    const accountRef = db.doc(`billingAccounts/${identifier(item.get('accountId'), 'Conta')}`);
    const [account, toPlan] = await tx.getAll(accountRef, db.doc(`plans/${identifier(item.get('toPlanId'), 'Plano')}`));
    if (!account.exists || !toPlan.exists || toPlan.get('active') !== true || isFreePlan(toPlan, toPlan.id)) throw new HttpsError('failed-precondition', 'Plano ou assinatura indisponível.');
    const next = paidAccount(account.data(), toPlan, Date.now());
    tx.set(accountRef, { ...next, updatedAt: FieldValue.serverTimestamp() });
    writeMirrors(tx, db, next, toPlan, uid);
    if (item.get('direction') === 'REFUND' && item.get('amountCents') > 0) {
      tx.create(db.collection('billingRequests').doc(), { kind: 'REFUND', status: 'PENDING', accountId: account.id, ownerName: item.get('ownerName') ?? '',
        fromPlanId: item.get('fromPlanId'), fromPlanName: item.get('fromPlanName'), toPlanId: toPlan.id, toPlanName: toPlan.get('name') ?? toPlan.id,
        direction: 'REFUND', amountCents: item.get('amountCents'), days: item.get('days'), reason: 'PLAN_DOWNGRADE', createdAt: FieldValue.serverTimestamp(),
        // The administrator who confirmed the change gets no push about it.
        createdByPlatform: uid });
    }
    tx.update(ref, { status: 'APPROVED', ...decided });
    return { billingRequestId, status: 'APPROVED', planId: toPlan.id };
  });
});

/// Daily routine (conectar pendente: agendador diário em produção): applies the
/// cancellations scheduled for the end of the cycle. Runs by command locally.
export async function applyDueCancellations(db, now = Date.now()) {
  const due = await db.collection('billingAccounts').where('cancelAtCycleEnd.at', '<=', Timestamp.fromMillis(now)).limit(100).get();
  let applied = 0;
  for (const doc of due.docs) {
    applied += await db.runTransaction(async (tx) => {
      const [account, freePlan] = await tx.getAll(doc.ref, db.doc(`plans/${FREE_PLAN_ID}`));
      const scheduled = account.get('cancelAtCycleEnd');
      if (!scheduled || scheduled.at.toMillis() > now || !freePlan.exists) return 0;
      const next = freeAccount(account.data(), freePlan, scheduled.keepTenantId);
      tx.set(account.ref, { ...next, updatedAt: FieldValue.serverTimestamp(), cancelledAt: Timestamp.fromMillis(now) });
      writeMirrors(tx, db, next, freePlan, 'billing-routine');
      return 1;
    });
  }
  return applied;
}

export const runBillingRoutine = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, [], 'Rotina');
  await adminAccess(db, db, uid); await requireEmailSession(request, db, uid);
  return { cancellationsApplied: await applyDueCancellations(db) };
});
