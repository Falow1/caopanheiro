import { FieldPath, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { civil, zonedInstant } from './calendar.js';
import { companyReleased, subscriptionValid } from './access_policy.js';

export function validPolicy(policy) {
  if (!policy || !Number.isSafeInteger(policy.slotMinutes) || policy.slotMinutes < 5 || policy.slotMinutes > 120) return false;
  try { new Intl.DateTimeFormat('en', { timeZone: policy.timeZone }).format(); } catch { return false; }
  if (typeof policy.timeZone !== 'string' || !policy.days) return false;
  let open = false;
  for (let day = 1; day <= 7; day++) {
    const periods = policy.days[day] ?? [];
    if (!Array.isArray(periods) || periods.length > 4) return false;
    let end = -1;
    for (const period of periods) {
      if (!Number.isSafeInteger(period.start) || !Number.isSafeInteger(period.end)
        || period.start < 0 || period.end > 1440 || period.start >= period.end || period.start < end) return false;
      end = period.end; open = true;
    }
  }
  return open;
}
export function onboardingState({ tenant, users, policy, services, professionals, subscription, plan, now = Date.now() }) {
  const manager = users.some((u) => u.active && u.role === 'MANAGER');
  const schedule = validPolicy(policy);
  const usableServices = services.filter((s) => s.active === true && Number.isSafeInteger(s.durationMinutes)
    && s.durationMinutes > 0 && s.durationMinutes <= 1440 && Number.isSafeInteger(s.priceCents) && s.priceCents >= 0);
  const activeProfessionals = professionals.filter((p) => p.active === true);
  const tenantActive = companyReleased(tenant);
  const subscriptionActive = subscriptionValid(subscription, now) && subscription.tenantId === tenant.id;
  const availability = schedule && activeProfessionals.some((p) => usableServices.some((service) =>
    Object.entries(policy.days).some(([day, periods]) => periods.some((period) =>
      (p.availability?.[day] ?? (p.availability ? [] : periods)).some((own) => {
        const start = Math.max(period.start, own.start);
        const aligned = Math.ceil(start / policy.slotMinutes) * policy.slotMinutes;
        return Math.min(period.end, own.end) - aligned >= service.durationMinutes;
      })))));
  return [
    { label: 'Empresa criada', completed: true },
    { label: 'Gestor cadastrado', completed: manager },
    { label: 'Horário de funcionamento configurado', completed: schedule },
    { label: 'Serviço cadastrado', completed: usableServices.length > 0 },
    { label: 'Profissional cadastrado', completed: activeProfessionals.length > 0 },
    { label: 'Pronto para receber agendamentos', completed: !!(manager && availability && tenantActive && subscriptionActive && plan?.active) },
  ];
}

export function monthBounds(now, zone) {
  const { day } = civil(now, zone);
  const first = day.slice(0, 7) + '-01';
  const next = new Date(Date.UTC(Number(first.slice(0, 4)), Number(first.slice(5, 7)), 1)).toISOString().slice(0, 10);
  const start = zonedInstant(first, 0, zone), end = zonedInstant(next, 0, zone);
  if (start == null || end == null) throw new HttpsError('failed-precondition', 'Revise o fuso horário da agenda.');
  return { start, end, month: first.slice(0, 7), timeZone: zone };
}
export async function tenantOverview(db, tenantDoc, users, now = Date.now()) {
  const ref = tenantDoc.ref;
  const [policyDoc, servicesPage, professionalPage, subscriptionDoc, planDoc] = await Promise.all([
    ref.collection('settings').doc('scheduling').get(),
    ref.collection('services').where('active', '==', true).limit(1001).get(),
    ref.collection('professionals').where('active', '==', true).limit(101).get(),
    db.doc(`subscriptions/${tenantDoc.id}`).get(),
    tenantDoc.get('planId') ? db.collection('plans').doc(tenantDoc.get('planId')).get() : null,
  ]);
  if (servicesPage.size > 1000 || professionalPage.size > 100) throw new HttpsError('resource-exhausted', 'Empresa excede o limite da consulta administrativa.');
  const policy = policyDoc.data(), services = servicesPage.docs.map((d) => d.data()), professionals = professionalPage.docs.map((d) => d.data());
  const zone = policy?.timeZone ?? 'America/Cuiaba';
  const bounds = monthBounds(now, zone);
  const [customersCount, appointmentsCount] = await Promise.all([
    ref.collection('customers').count().get(),
    ref.collection('appointments').where('startsAt', '>=', Timestamp.fromMillis(bounds.start))
      .where('startsAt', '<', Timestamp.fromMillis(bounds.end)).count().get(),
  ]);
  let pets = 0, cursor, processed = 0;
  do {
    let query = ref.collection('customers').orderBy(FieldPath.documentId()).select('pets').limit(500);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get(); processed += page.size;
    if (processed > 10000) throw new HttpsError('resource-exhausted', 'Contagem de pets requer processamento agregado para esta empresa.');
    for (const d of page.docs) pets += Object.keys(d.get('pets') ?? {}).length;
    cursor = page.size === 500 ? page.docs.at(-1).id : null;
  } while (cursor);
  return {
    onboarding: onboardingState({ tenant: { ...tenantDoc.data(), id: tenantDoc.id }, users, policy, services, professionals, subscription: subscriptionDoc.data(), plan: planDoc?.data(), now }),
    metrics: { professionals: professionalPage.size, services: servicesPage.size, tutors: customersCount.data().count,
      pets, monthlyAppointments: appointmentsCount.data().count, ...bounds },
  };
}
