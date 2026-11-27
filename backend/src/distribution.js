// Distribution of the pets of one booking among the professionals.
//
// Each pet is done by one professional, its services in a row. A professional
// with several pets of the booking does them one after the other, from the
// start of the booking; different professionals work at the same time. So the
// booking lasts as long as the busiest professional (the real time), not the
// sum of every service (the summed time), which stays the quote.
//
// Pure: no Firestore. scheduling.js reads the day and passes the periods,
// blocks and reservations; here they become free minutes and segments.

export const DISTRIBUTIONS = Object.freeze(['ANY', 'SPECIFIC']);

/** Minutes of each pet: the sum of its services. */
export function petMinutes(items) {
  return items.map((item) => ({ petId: item.pet.id, minutes: item.services.reduce((sum, service) => sum + service.durationMinutes, 0) }));
}

/** End of the period that contains [start], or [start] when none does. */
export function periodEnd(periods, start) {
  const period = (periods ?? []).find((value) => value.start <= start && start < value.end);
  return period ? period.end : start;
}

/** Busy intervals of a stored reservation, per professional. A reservation
 * saved before the distribution has a single one, for all its pets. */
export function reservationSegments(value) {
  if (Array.isArray(value?.segments) && value.segments.length) return value.segments;
  return [{ professionalId: value?.professionalId, start: value?.start, end: value?.end, petIds: value?.petIds ?? [] }];
}

/** Minutes a professional is free from [start] without a gap: inside the
 * company period and the professional's own period (null means the company
 * hours), before the next block and the next reservation of that professional.
 * Zero when [start] itself is busy. */
export function freeMinutes({ companyPeriods, professionalPeriods, blocks = [], reservations = [], professionalId, start, excludeId = null }) {
  let end = periodEnd(companyPeriods, start);
  if (professionalPeriods) end = Math.min(end, periodEnd(professionalPeriods, start));
  if (end <= start) return 0;
  for (const block of blocks) {
    if (block.start <= start && start < block.end) return 0;
    if (block.start > start) end = Math.min(end, block.start);
  }
  for (const [id, value] of reservations) {
    if (id === excludeId) continue;
    for (const segment of reservationSegments(value)) {
      if (segment.professionalId !== professionalId) continue;
      if (segment.start <= start && start < segment.end) return 0;
      if (segment.start > start) end = Math.min(end, segment.start);
    }
  }
  return Math.max(0, Math.min(end, 1440) - start);
}

/** Segments of an assignment (petId → professionalId), from [start]: the pets
 * of each professional in the order of the booking. */
export function segmentsFor(pets, assignment, start) {
  const next = new Map();
  return pets.map(({ petId, minutes }) => {
    const professionalId = assignment.get(petId);
    const from = next.get(professionalId) ?? start;
    next.set(professionalId, from + minutes);
    return { petId, professionalId, start: from, end: from + minutes };
  });
}

/** Minutes each professional works in an assignment. */
export function loads(pets, assignment) {
  const result = new Map();
  for (const { petId, minutes } of pets) {
    const id = assignment.get(petId);
    result.set(id, (result.get(id) ?? 0) + minutes);
  }
  return result;
}

/** Professionals of an assignment that lack time for their pets, with the
 * minutes asked and the minutes free. Empty when it fits. */
export function overloaded(pets, assignment, free) {
  return [...loads(pets, assignment)].filter(([id, minutes]) => minutes > (free.get(id) ?? 0)).map(([id, minutes]) => ({ professionalId: id, minutes, free: free.get(id) ?? 0 }));
}

/** Automatic distribution ("Qualquer profissional"): the shortest booking,
 * then the fewest professionals, then the order of [professionals]
 * ([{ id, free }]). Null when no assignment fits. The search is exact for the
 * usual sizes and stops after [limit] steps with the best one found, starting
 * from the greedy answer (longest pet first, to the professional that ends
 * earliest). */
export function bestDistribution(pets, professionals, limit = 5000) {
  const order = pets.map((pet, index) => ({ ...pet, index })).sort((a, b) => b.minutes - a.minutes || a.index - b.index);
  const count = professionals.length, work = new Array(count).fill(0);
  let best = null;
  const keep = (choice, makespan, used) => {
    best = { makespan, used, assignment: new Map(order.map((pet, k) => [pet.petId, professionals[choice[k]].id])) };
  };
  // Greedy start.
  const greedy = [];
  for (const pet of order) {
    let chosen = -1;
    for (let j = 0; j < count; j++) {
      if (work[j] + pet.minutes > professionals[j].free) continue;
      if (chosen < 0 || work[j] + pet.minutes < work[chosen] + pet.minutes) chosen = j;
    }
    if (chosen < 0) { greedy.length = 0; break; }
    work[chosen] += pet.minutes; greedy.push(chosen);
  }
  if (greedy.length === order.length) keep(greedy, Math.max(...work), work.filter(Boolean).length);
  work.fill(0);
  const choice = [];
  let steps = 0;
  const search = (k, makespan, used) => {
    if (++steps > limit) return;
    if (best && (makespan > best.makespan || (makespan === best.makespan && used >= best.used))) return;
    if (k === order.length) { keep(choice, makespan, used); return; }
    const minutes = order[k].minutes, seen = new Set();
    for (let j = 0; j < count; j++) {
      const load = work[j] + minutes;
      if (load > professionals[j].free) continue;
      // Two professionals with the same work and the same free time give the
      // same result: only the first is tried.
      const key = `${work[j]}:${professionals[j].free}`;
      if (seen.has(key)) continue;
      seen.add(key);
      work[j] = load; choice[k] = j;
      search(k + 1, Math.max(makespan, load), used + (work[j] === minutes ? 1 : 0));
      work[j] -= minutes;
      if (steps > limit) return;
    }
  };
  search(0, 0, 0);
  return best;
}

/** Validates the professionals chosen per pet ("Profissionais específicos"):
 * every pet once, nothing else. Returns the map petId → professionalId. */
export function assignmentInput(value, petIds, invalid) {
  if (!Array.isArray(value) || value.length !== petIds.length) invalid('Escolha o profissional de cada pet.');
  const result = new Map();
  for (const row of value) {
    if (row === null || typeof row !== 'object' || Array.isArray(row)) invalid('Escolha o profissional de cada pet.');
    const keys = Object.keys(row);
    if (keys.length !== 2 || !keys.includes('petId') || !keys.includes('professionalId')) invalid('Escolha o profissional de cada pet.');
    if (!petIds.includes(row.petId) || result.has(row.petId)) invalid('Escolha o profissional de cada pet.');
    if (typeof row.professionalId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(row.professionalId)) invalid('Profissional inválido.');
    result.set(row.petId, row.professionalId);
  }
  return result;
}

/** UID of the professional of one pet; items saved before the distribution
 * follow the professional of the appointment. */
export function petProfessionalUid(appointment, petId) {
  const item = (appointment?.items ?? []).find((value) => value.pet?.id === petId);
  return item && Object.hasOwn(item, 'professionalUid') ? item.professionalUid ?? null : appointment?.professionalUid ?? null;
}

/** True when [uid] does the pet [petId], or every pet when [petId] is null. */
export function assignedTo(appointment, uid, petId = null) {
  if (!uid) return false;
  const items = appointment?.items ?? [];
  if (petId) return petProfessionalUid(appointment, petId) === uid;
  if (!items.length) return appointment?.professionalUid === uid;
  return items.every((item) => petProfessionalUid(appointment, item.pet?.id) === uid);
}

/** Every professional account with at least one pet of the appointment. */
export function involvedUids(appointment) {
  const items = appointment?.items ?? [];
  const uids = items.length ? items.map((item) => petProfessionalUid(appointment, item.pet?.id)) : [appointment?.professionalUid];
  return [...new Set(uids.filter(Boolean))];
}
