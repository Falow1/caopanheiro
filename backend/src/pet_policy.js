import { HttpsError } from 'firebase-functions/v2/https';
import { PET_BREEDS, PET_SIZES, PET_SPECIES, matchLegacyBreed, otherBreed, petBreed } from './pet_breeds.js';
import { invalid, object, text } from './runtime.js';

/// Which pets a petshop serves (tenants/{tenantId}/settings/pets) and the pets
/// the team marked "Não atender este pet" (tenants/{tenantId}/petBlocks/{customerId}).
/// Both stay apart from the customer record: nothing here changes the pet data.
/// Without a saved rule the petshop serves every pet, as before the rule existed.

export const PET_POLICY_DEFAULT = Object.freeze({
  dogs: Object.freeze({ mode: 'ALL', sizes: Object.freeze([]), breeds: Object.freeze([]), excluded: Object.freeze([]) }),
  cats: Object.freeze({ mode: 'ALL', breeds: Object.freeze([]), excluded: Object.freeze([]) }),
  puppies: 'RULE',
});
export const petPolicyRef = (db, tenantId) => db.doc(`tenants/${tenantId}/settings/pets`);
export const petBlocksRef = (db, tenantId, customerId) => db.doc(`tenants/${tenantId}/petBlocks/${customerId}`);

function codes(value, species, label) {
  if (!Array.isArray(value) || value.length > PET_BREEDS.length || new Set(value).size !== value.length) invalid(`${label}: lista inválida.`);
  for (const code of value) if (petBreed(code)?.species !== species) invalid(`${label}: raça inválida.`);
  return [...value].sort();
}

/// Rule sent by the manager. Each list keeps what was chosen even while
/// another mode is active, so switching modes does not lose the list.
export function petPolicyValue(input) {
  object(input, ['dogs', 'cats', 'puppies'], 'Pets atendidos');
  object(input.dogs, ['mode', 'sizes', 'breeds', 'excluded'], 'Cachorros');
  object(input.cats, ['mode', 'breeds', 'excluded'], 'Gatos');
  const { dogs, cats } = input;
  if (!['ALL', 'SIZES', 'LIST', 'NONE'].includes(dogs.mode)) invalid('Cachorros: escolha como o petshop atende.');
  if (!['ALL', 'LIST', 'NONE'].includes(cats.mode)) invalid('Gatos: escolha como o petshop atende.');
  if (!['RULE', 'ALL', 'NONE'].includes(input.puppies)) invalid('Filhotes: escolha como o petshop atende.');
  if (!Array.isArray(dogs.sizes) || new Set(dogs.sizes).size !== dogs.sizes.length || dogs.sizes.some((size) => !PET_SIZES.includes(size))) invalid('Cachorros: porte inválido.');
  const value = {
    dogs: { mode: dogs.mode, sizes: PET_SIZES.filter((size) => dogs.sizes.includes(size)), breeds: codes(dogs.breeds, 'Cachorro', 'Cachorros'), excluded: codes(dogs.excluded, 'Cachorro', 'Cachorros') },
    cats: { mode: cats.mode, breeds: codes(cats.breeds, 'Gato', 'Gatos'), excluded: codes(cats.excluded, 'Gato', 'Gatos') },
    puppies: input.puppies,
  };
  if (value.dogs.mode === 'SIZES' && !value.dogs.sizes.length) invalid('Cachorros: escolha ao menos um porte.');
  if (value.dogs.mode === 'LIST' && !value.dogs.breeds.length) invalid('Cachorros: escolha ao menos uma raça.');
  if (value.cats.mode === 'LIST' && !value.cats.breeds.length) invalid('Gatos: escolha ao menos uma raça.');
  return value;
}

/// Saved rule, tolerant of a document written by an older version.
export function storedPetPolicy(doc) {
  if (!doc?.exists) return { ...PET_POLICY_DEFAULT, version: 0 };
  const known = (list, species) => Array.isArray(list) ? list.filter((code) => petBreed(code)?.species === species) : [];
  const dogs = doc.get('dogs') ?? {}, cats = doc.get('cats') ?? {};
  return {
    dogs: { mode: ['ALL', 'SIZES', 'LIST', 'NONE'].includes(dogs.mode) ? dogs.mode : 'ALL', sizes: PET_SIZES.filter((size) => dogs.sizes?.includes?.(size)),
      breeds: known(dogs.breeds, 'Cachorro'), excluded: known(dogs.excluded, 'Cachorro') },
    cats: { mode: ['ALL', 'LIST', 'NONE'].includes(cats.mode) ? cats.mode : 'ALL', breeds: known(cats.breeds, 'Gato'), excluded: known(cats.excluded, 'Gato') },
    puppies: ['RULE', 'ALL', 'NONE'].includes(doc.get('puppies')) ? doc.get('puppies') : 'RULE',
    version: Number.isSafeInteger(doc.get('version')) ? doc.get('version') : 0,
  };
}

const today = (now) => now.toISOString().slice(0, 10);
/// A puppy is under 12 months old, counted from the birth date.
export function isPuppy(birthDate, now = new Date()) {
  if (typeof birthDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) return false;
  const firstBirthday = `${String(Number(birthDate.slice(0, 4)) + 1).padStart(4, '0')}${birthDate.slice(4)}`;
  return today(now) < firstBirthday;
}

/// Reasons, in the order they are checked. A block comes first; "Filhotes:
/// atender todos" overrides sizes, lists and exclusions, not a species the
/// petshop does not serve.
export const PET_SERVICE_REASONS = Object.freeze(['PET_BLOCKED', 'SPECIES_NOT_SERVED', 'PUPPY_NOT_SERVED', 'BREED_NOT_SERVED', 'SIZE_NOT_SERVED']);
export function evaluatePet(policy, pet, { blocked = false, now = new Date() } = {}) {
  const no = (reason) => ({ served: false, reason });
  if (blocked) return no('PET_BLOCKED');
  const cat = pet.species === 'Gato';
  const rule = cat ? policy.cats : policy.dogs;
  const breed = petBreed(pet.breedCode) ?? otherBreed(pet.species, pet.size);
  if (rule.mode === 'NONE') return no('SPECIES_NOT_SERVED');
  const puppy = isPuppy(pet.birthDate, now);
  if (puppy && policy.puppies === 'NONE') return no('PUPPY_NOT_SERVED');
  if (puppy && policy.puppies === 'ALL') return { served: true };
  if (rule.mode === 'LIST') return rule.breeds.includes(breed.code) ? { served: true } : no('BREED_NOT_SERVED');
  if (!cat && rule.mode === 'SIZES' && !rule.sizes.includes(breed.size)) return no('SIZE_NOT_SERVED');
  if (rule.excluded.includes(breed.code)) return no('BREED_NOT_SERVED');
  return { served: true };
}

/// Message for the team or for a tutor. The tutor never reads the internal
/// reason of a block: only that the petshop is not serving the pet by the app.
export function petServiceMessage(reason, pet, { tutor = false, petshop = 'Este petshop' } = {}) {
  const breed = petBreed(pet.breedCode);
  switch (reason) {
    case 'PET_BLOCKED': return tutor ? `${petshop} não está atendendo ${pet.name} pelo app. Fale com o petshop.`
      : `${pet.name} está marcado como "Não atender este pet".`;
    case 'SPECIES_NOT_SERVED': return `${petshop} não atende ${pet.species === 'Gato' ? 'gatos' : 'cachorros'}.`;
    case 'PUPPY_NOT_SERVED': return `${petshop} não atende filhotes com menos de 12 meses.`;
    case 'SIZE_NOT_SERVED': return `${petshop} não atende cachorros de porte ${String(breed?.size ?? pet.size).toLowerCase()}.`;
    default: return `${petshop} não atende ${breed?.kind === 'BREED' ? 'a raça ' : ''}${breed?.name ?? pet.breed}.`;
  }
}

/// A pet as stored, with breed, size and code from the list. Pets saved before
/// the list are converted when read, without changing the database: the old
/// text is looked up on the list; what is not found becomes "Outra raça" of
/// the size it had, keeps the text in legacyBreed and asks for the breed on
/// the next edit (breedPending).
export function normalizedPet(stored) {
  const { breedPending, service, block, ...pet } = stored ?? {};
  const species = pet.species === 'Gato' ? 'Gato' : 'Cachorro';
  const saved = petBreed(pet.breedCode);
  if (saved?.species === species && !(saved.kind === 'OTHER' && pet.legacyBreed)) return { ...pet, species, breedCode: saved.code, breed: saved.name, size: saved.size };
  if (!saved) {
    const matched = matchLegacyBreed(species, pet.breed, pet.size);
    if (matched) return { ...pet, species, breedCode: matched.code, breed: matched.name, size: matched.size };
  }
  const other = saved?.species === species ? saved : otherBreed(species, pet.size);
  return { ...pet, species, breedCode: other.code, breed: other.name, size: other.size, legacyBreed: String(pet.legacyBreed ?? pet.breed ?? ''), breedPending: true };
}

function birthDateValue(value) {
  const birthDate = text(value, 'Nascimento', 10, 10);
  const parsed = new Date(`${birthDate}T00:00:00.000Z`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(birthDate) || !Number.isFinite(parsed.getTime())
    || parsed.toISOString().slice(0, 10) !== birthDate || birthDate > new Date().toISOString().slice(0, 10)) invalid('Nascimento inválido.');
  return birthDate;
}

export const petInputFields = ['name', 'species', 'breedCode', 'breed', 'size', 'birthDate', 'notes', 'breedSuggestion'];
/// Pet sent by the team or the tutor. Current apps send breedCode and the
/// server takes the breed name and the size from the list; apps released
/// before the list send the breed text and the size, which are looked up the
/// same way as an old pet.
export function petInput(value, petId) {
  object(value, petInputFields, 'Pet');
  const species = text(value.species, 'Espécie', 30, 1);
  if (!PET_SPECIES.includes(species)) invalid('Espécie inválida.');
  const base = { id: petId, name: text(value.name, 'Nome', 100, 1), species, birthDate: birthDateValue(value.birthDate), notes: text(value.notes ?? '', 'Observações', 2000) };
  let pet;
  if (value.breedCode != null) {
    if (value.breed != null || value.size != null) invalid('Envie somente a raça da lista.');
    const breed = petBreed(value.breedCode);
    if (breed?.species !== species) invalid('Escolha a raça na lista.');
    pet = { ...base, breedCode: breed.code, breed: breed.name, size: breed.size };
  } else {
    const typed = text(value.breed, 'Raça', 100, 1), size = text(value.size, 'Porte', 30, 1);
    if (!PET_SIZES.includes(size)) invalid('Espécie ou porte inválido.');
    pet = normalizedPet({ ...base, breed: typed, size });
    delete pet.breedPending;
  }
  const suggestion = value.breedSuggestion == null ? null : text(value.breedSuggestion, 'Raça sugerida', 60, 2);
  if (suggestion && petBreed(pet.breedCode)?.kind !== 'OTHER') invalid('A sugestão de raça vale só para "Outra raça".');
  return { pet, suggestion };
}

/// The old text of a pet converted to "Outra raça" survives an edit by an app
/// released before the list, which sends back the list name it read.
export function keepLegacyBreed(pet, previous) {
  if (!previous || pet.legacyBreed || previous.breedCode !== pet.breedCode || !previous.legacyBreed) return pet;
  return { ...pet, legacyBreed: previous.legacyBreed };
}

/// Refuses a pet the petshop does not serve. The tutor reads the neutral text.
export function refuseUnservedPet(policy, pet, { blocked = false, tutor = false, petshop } = {}) {
  const result = evaluatePet(policy, pet, { blocked });
  if (result.served) return;
  throw new HttpsError('failed-precondition', petServiceMessage(result.reason, pet, { tutor, petshop }), { reason: 'PET_NOT_SERVED', petId: pet.id, service: result.reason });
}

/// Rule and blocks for the customers of one response.
export async function petServiceContext(reader, db, tenantId, customerIds) {
  const ids = [...new Set(customerIds)];
  const [policy, ...blocks] = await reader.getAll(petPolicyRef(db, tenantId), ...ids.map((id) => petBlocksRef(db, tenantId, id)));
  return { policy: storedPetPolicy(policy), blocks: new Map(ids.map((id, index) => [id, blocks[index].get('pets') ?? {}])) };
}

/// Pets of a customer response with whether the petshop serves each one. The
/// team also reads the block; the tutor reads only the petshop phone.
export function servedCustomer(customer, context, { team, contactPhone = '' }) {
  const blocks = context.blocks.get(customer.id) ?? {};
  return { ...customer, pets: customer.pets.map((pet) => {
    const block = blocks[pet.id];
    const result = evaluatePet(context.policy, pet, { blocked: !!block });
    return { ...pet, service: result.served ? { served: true } : { served: false, reason: result.reason, ...(team ? {} : { contactPhone }) },
      ...(team && block ? { block: { reason: block.reason, createdAt: block.createdAt ?? null, createdByName: block.createdByName ?? null } } : {}) };
  }) };
}

export const publicPetPolicy = ({ dogs, cats, puppies, version }) => ({ dogs, cats, puppies, version });
