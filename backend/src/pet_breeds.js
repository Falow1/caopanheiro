/// Breed list of the platform: the single source of breed names, sizes and
/// icons. The code of an entry is stored in the pet and never changes; names,
/// other names and icons may be improved. tool/generate-pet-breeds.mjs writes
/// the Dart copy (packages/caopanheiro_contracts/lib/src/pet_breed_catalog.dart).
///
/// Size follows the typical adult weight: Pequeno up to about 10 kg, Médio
/// from 10 to 25 kg and Grande above 25 kg. Cats are listed with a size for
/// display only; the petshop rule for cats does not use it.
///
/// kind: BREED (a breed), SRD (no defined breed) or OTHER (a breed that is not
/// on the list). SRD and OTHER exist once per size, so the size still comes
/// from the list.

export const PET_SPECIES = Object.freeze(['Cachorro', 'Gato']);
export const PET_SIZES = Object.freeze(['Pequeno', 'Médio', 'Grande']);

const srdAliases = ['vira-lata', 'viralata', 'vira lata', 'srd', 'sem raça', 'sem raça definida', 'mestiço', 'misturado',
  'caramelo', 'vira-lata caramelo', 'não tem raça', 'sem pedigree'];
const otherAliases = ['outra', 'outra raça', 'raça não listada', 'não está na lista'];
const dog = (code, name, size, aliases = [], icon = code, kind = 'BREED') =>
  ({ code, name, species: 'Cachorro', size, kind, icon, aliases });
const cat = (code, name, aliases = [], icon = code, kind = 'BREED', size = 'Pequeno') =>
  ({ code, name, species: 'Gato', size, kind, icon, aliases });

const entries = [
  dog('srd-pequeno', 'SRD (vira-lata) – pequeno porte', 'Pequeno', srdAliases, 'srd-pequeno', 'SRD'),
  dog('srd-medio', 'SRD (vira-lata) – médio porte', 'Médio', srdAliases, 'srd-medio-caramelo', 'SRD'),
  dog('srd-grande', 'SRD (vira-lata) – grande porte', 'Grande', srdAliases, 'srd-grande', 'SRD'),
  dog('outra-pequeno', 'Outra raça – pequeno porte', 'Pequeno', otherAliases, 'outra-raca-cachorro', 'OTHER'),
  dog('outra-medio', 'Outra raça – médio porte', 'Médio', otherAliases, 'outra-raca-cachorro', 'OTHER'),
  dog('outra-grande', 'Outra raça – grande porte', 'Grande', otherAliases, 'outra-raca-cachorro', 'OTHER'),

  dog('fila-brasileiro', 'Fila Brasileiro', 'Grande', ['fila']),
  dog('terrier-brasileiro', 'Terrier Brasileiro (Fox Paulistinha)', 'Pequeno', ['fox paulistinha', 'foxinho', 'fox brasileiro', 'paulistinha']),
  dog('buldogue-campeiro', 'Buldogue Campeiro', 'Grande', ['bulldog campeiro', 'campeiro']),
  dog('dogue-brasileiro', 'Dogue Brasileiro', 'Grande', ['bull boxer brasileiro']),
  dog('ovelheiro-gaucho', 'Ovelheiro Gaúcho', 'Médio', ['ovelheiro']),

  dog('affenpinscher', 'Affenpinscher', 'Pequeno', ['affen']),
  dog('bichon-frise', 'Bichon Frisé', 'Pequeno', ['bichon', 'bichon frise']),
  dog('bichon-havanes', 'Bichon Havanês', 'Pequeno', ['havanês', 'havanese']),
  dog('boston-terrier', 'Boston Terrier', 'Pequeno', ['boston']),
  dog('buldogue-frances', 'Buldogue Francês', 'Pequeno', ['bulldog francês', 'buldog francês', 'bulldog frances', 'french bulldog', 'frenchie', 'buldogue frances']),
  dog('cavalier-king-charles', 'Cavalier King Charles Spaniel', 'Pequeno', ['cavalier', 'king charles']),
  dog('chihuahua-pelo-curto', 'Chihuahua de pelo curto', 'Pequeno', ['chihuahua', 'chiuaua', 'chihuaua', 'chiwawa']),
  dog('chihuahua-pelo-longo', 'Chihuahua de pelo longo', 'Pequeno', ['chihuahua', 'chiuaua', 'chihuaua', 'chiwawa']),
  dog('coton-de-tulear', 'Coton de Tuléar', 'Pequeno', ['coton']),
  dog('dachshund-pelo-curto', 'Dachshund (salsicha) de pelo curto', 'Pequeno', ['dachshund', 'salsicha', 'teckel', 'cofap', 'daschund', 'dachshound']),
  dog('dachshund-pelo-longo', 'Dachshund (salsicha) de pelo longo', 'Pequeno', ['dachshund', 'salsicha', 'teckel', 'cofap', 'daschund', 'dachshound']),
  dog('dachshund-pelo-duro', 'Dachshund (salsicha) de pelo duro', 'Pequeno', ['dachshund', 'salsicha', 'teckel', 'cofap', 'daschund', 'dachshound']),
  dog('griffon-de-bruxelas', 'Griffon de Bruxelas', 'Pequeno', ['griffon', 'grifon']),
  dog('jack-russell-terrier', 'Jack Russell Terrier', 'Pequeno', ['jack russell', 'jack russel', 'jack']),
  dog('lhasa-apso', 'Lhasa Apso', 'Pequeno', ['lhasa', 'lasa', 'lasa apso', 'lhasa apso']),
  dog('lulu-da-pomerania', 'Lulu da Pomerânia (Spitz Alemão Anão)', 'Pequeno', ['lulu', 'pomerania', 'pomeranian', 'spitz alemão', 'spitz alemão anão', 'spitz', 'lulu da pomerania']),
  dog('maltes', 'Maltês', 'Pequeno', ['maltes', 'maltese', 'bichon maltês']),
  dog('papillon', 'Papillon', 'Pequeno', ['papilon']),
  dog('pequines', 'Pequinês', 'Pequeno', ['pequines', 'pekingese']),
  dog('pinscher-miniatura', 'Pinscher Miniatura', 'Pequeno', ['pinscher', 'pincher', 'pinsher', 'pinscher zero', 'pinscher 1', 'pinscher 2']),
  dog('pug', 'Pug', 'Pequeno', ['pug']),
  dog('west-highland-white-terrier', 'West Highland White Terrier', 'Pequeno', ['westie', 'west highland', 'west terrier']),
  dog('cairn-terrier', 'Cairn Terrier', 'Pequeno', ['cairn']),
  dog('scottish-terrier', 'Scottish Terrier', 'Pequeno', ['scottie', 'terrier escocês']),
  dog('fox-terrier', 'Fox Terrier', 'Pequeno', ['fox']),
  dog('spitz-japones', 'Spitz Japonês', 'Pequeno', ['spitz japones', 'japanese spitz']),
  dog('galgo-italiano', 'Galgo Italiano', 'Pequeno', ['italian greyhound', 'piccolo levriero']),
  dog('cao-de-crista-chines', 'Cão de Crista Chinês', 'Pequeno', ['crista chinês', 'chinese crested', 'cão chinês de crista']),
  dog('yorkshire-terrier', 'Yorkshire Terrier', 'Pequeno', ['yorkshire', 'york', 'yorkie', 'yorkshire terrier']),
  dog('poodle-toy', 'Poodle Toy', 'Pequeno', ['poodle', 'poodle micro toy', 'micro toy', 'caniche', 'poodle toy'], 'poodle'),
  dog('poodle-anao', 'Poodle Anão (Miniatura)', 'Pequeno', ['poodle', 'poodle miniatura', 'poodle mini', 'caniche', 'poodle anao'], 'poodle'),
  dog('poodle-medio', 'Poodle Médio', 'Médio', ['poodle', 'caniche', 'poodle medio'], 'poodle'),
  dog('poodle-gigante', 'Poodle Gigante (Standard)', 'Grande', ['poodle', 'poodle standard', 'poodle padrão', 'caniche'], 'poodle'),
  dog('schnauzer-miniatura', 'Schnauzer Miniatura', 'Pequeno', ['schnauzer', 'schnauzer mini', 'schnauser', 'chinauzer', 'snauzer'], 'schnauzer'),
  dog('schnauzer-standard', 'Schnauzer Standard (Médio)', 'Médio', ['schnauzer', 'schnauzer médio', 'schnauser', 'chinauzer', 'snauzer'], 'schnauzer'),
  dog('shih-tzu', 'Shih Tzu', 'Pequeno', ['shitzu', 'shih tzu', 'shitsu', 'chitsu', 'shi tzu', 'xitsu']),
  dog('shiba-inu', 'Shiba Inu', 'Médio', ['shiba']),
  dog('pastor-de-shetland', 'Pastor de Shetland', 'Pequeno', ['sheltie', 'shetland']),
  dog('welsh-corgi-pembroke', 'Welsh Corgi Pembroke', 'Médio', ['corgi', 'welsh corgi']),
  dog('beagle', 'Beagle', 'Médio', ['beagle', 'bigle', 'biguel']),
  dog('cocker-spaniel-ingles', 'Cocker Spaniel Inglês', 'Médio', ['cocker', 'cocker inglês', 'cocker spaniel']),
  dog('cocker-spaniel-americano', 'Cocker Spaniel Americano', 'Médio', ['cocker', 'cocker americano', 'cocker spaniel']),
  dog('basenji', 'Basenji', 'Médio', ['basenji']),

  dog('american-pit-bull-terrier', 'Pit Bull (American Pit Bull Terrier)', 'Médio', ['pit bull', 'pitbull', 'pit', 'american pit bull']),
  dog('american-staffordshire-terrier', 'American Staffordshire Terrier', 'Médio', ['amstaff', 'staffordshire', 'american staffordshire']),
  dog('staffordshire-bull-terrier', 'Staffordshire Bull Terrier', 'Médio', ['staffbull', 'staffy', 'staffordshire bull']),
  dog('american-bully', 'American Bully', 'Grande', ['bully', 'american bully']),
  dog('bull-terrier', 'Bull Terrier', 'Grande', ['bull terrier', 'bulterrier'], 'bull-terrier'),
  dog('bull-terrier-miniatura', 'Bull Terrier Miniatura', 'Médio', ['bull terrier', 'bull terrier mini', 'bulterrier'], 'bull-terrier'),
  dog('buldogue-ingles', 'Buldogue Inglês', 'Médio', ['bulldog inglês', 'buldog inglês', 'bulldog ingles', 'english bulldog', 'bulldog', 'buldogue']),
  dog('buldogue-americano', 'Buldogue Americano', 'Grande', ['bulldog americano', 'american bulldog', 'buldog americano']),
  dog('basset-hound', 'Basset Hound', 'Médio', ['basset', 'baset']),
  dog('border-collie', 'Border Collie', 'Médio', ['border', 'border colie']),
  dog('pastor-australiano', 'Pastor Australiano', 'Médio', ['australian shepherd', 'aussie']),
  dog('boiadeiro-australiano', 'Boiadeiro Australiano', 'Médio', ['blue heeler', 'red heeler', 'cattle dog', 'heeler']),
  dog('chow-chow', 'Chow Chow', 'Médio', ['chow', 'chowchow', 'chau chau']),
  dog('shar-pei', 'Shar-pei', 'Médio', ['sharpei', 'shar pei', 'xarpei']),
  dog('husky-siberiano', 'Husky Siberiano', 'Médio', ['husky', 'huski', 'raski', 'siberian husky']),
  dog('samoieda', 'Samoieda', 'Médio', ['samoyed', 'samoeida']),
  dog('springer-spaniel-ingles', 'Springer Spaniel Inglês', 'Médio', ['springer']),
  dog('whippet', 'Whippet', 'Médio', ['whipet', 'uipet']),
  dog('dalmata', 'Dálmata', 'Grande', ['dalmata', 'dalmatian']),
  dog('schnauzer-gigante', 'Schnauzer Gigante', 'Grande', ['schnauzer', 'giant schnauzer', 'schnauser']),
  dog('vizsla', 'Vizsla', 'Médio', ['braco húngaro', 'visla']),
  dog('pointer-ingles', 'Pointer Inglês', 'Grande', ['pointer']),
  dog('setter-irlandes', 'Setter Irlandês', 'Grande', ['setter', 'irish setter']),
  dog('weimaraner', 'Weimaraner', 'Grande', ['weimaraner', 'braco de weimar', 'vaimaraner']),
  dog('collie', 'Collie (pelo longo)', 'Grande', ['collie', 'colie', 'lassie', 'rough collie']),
  dog('bobtail', 'Bobtail (Old English Sheepdog)', 'Grande', ['old english sheepdog', 'bob tail']),
  dog('pastor-belga-malinois', 'Pastor Belga Malinois', 'Grande', ['malinois', 'pastor belga', 'malinoa']),
  dog('boxer', 'Boxer', 'Grande', ['boxer', 'boxe']),

  dog('labrador-retriever', 'Labrador Retriever', 'Grande', ['labrador', 'lab', 'labrador retriever']),
  dog('golden-retriever', 'Golden Retriever', 'Grande', ['golden', 'golden retriver']),
  dog('pastor-alemao', 'Pastor Alemão', 'Grande', ['pastor', 'capa preta', 'german shepherd', 'pastor alemao']),
  dog('pastor-branco-suico', 'Pastor Branco Suíço', 'Grande', ['pastor branco', 'pastor alemão branco', 'white swiss shepherd']),
  dog('rottweiler', 'Rottweiler', 'Grande', ['rottweiler', 'rotweiler', 'rottweiller', 'rot', 'rotwailer']),
  dog('doberman', 'Dobermann', 'Grande', ['doberman', 'dobermam', 'dobermann']),
  dog('dogue-alemao', 'Dogue Alemão', 'Grande', ['dog alemão', 'great dane', 'dinamarquês', 'dogue alemao']),
  dog('dogue-de-bordeaux', 'Dogue de Bordeaux', 'Grande', ['bordeaux', 'dog de bordeaux', 'mastim francês']),
  dog('mastim-ingles', 'Mastim Inglês', 'Grande', ['mastiff', 'mastiff inglês']),
  dog('mastim-napolitano', 'Mastim Napolitano', 'Grande', ['napolitano', 'mastino napoletano']),
  dog('cane-corso', 'Cane Corso', 'Grande', ['corso', 'cane corso italiano']),
  dog('dogo-argentino', 'Dogo Argentino', 'Grande', ['dogo', 'dogo argentino']),
  dog('boiadeiro-bernes', 'Boiadeiro Bernês', 'Grande', ['bernês', 'bernese', 'bernese mountain dog', 'boiadeiro bernes']),
  dog('sao-bernardo', 'São Bernardo', 'Grande', ['sao bernardo', 'saint bernard', 'são bernardo']),
  dog('terra-nova', 'Terra Nova', 'Grande', ['newfoundland', 'terranova']),
  dog('akita-inu', 'Akita Inu', 'Grande', ['akita', 'akita japonês']),
  dog('akita-americano', 'Akita Americano', 'Grande', ['akita', 'american akita']),
  dog('malamute-do-alasca', 'Malamute do Alasca', 'Grande', ['malamute', 'alaskan malamute']),
  dog('rhodesian-ridgeback', 'Rhodesian Ridgeback', 'Grande', ['rhodesian', 'ridgeback']),
  dog('galgo-ingles', 'Galgo Inglês (Greyhound)', 'Grande', ['greyhound', 'galgo', 'grey hound']),
  dog('galgo-afegao', 'Galgo Afegão', 'Grande', ['afghan hound', 'afegão', 'galgo afegao']),
  dog('leonberger', 'Leonberger', 'Grande', ['leonberg']),
  dog('bullmastiff', 'Bullmastiff', 'Grande', ['bull mastiff']),
  dog('bloodhound', 'Bloodhound (Cão de Santo Humberto)', 'Grande', ['cão de santo humberto', 'blood hound', 'santo humberto']),
  dog('mastim-tibetano', 'Mastim Tibetano', 'Grande', ['tibetan mastiff', 'mastiff tibetano']),

  cat('gato-srd', 'SRD (vira-lata)', ['vira-lata', 'viralata', 'vira lata', 'srd', 'sem raça', 'sem raça definida', 'mestiço', 'misturado',
    'rajado', 'tigrado', 'comum', 'gato de rua', 'não tem raça', 'sem pedigree'], 'srd-gato', 'SRD'),
  cat('gato-srd-frajola', 'SRD frajola (preto e branco)', ['frajola', 'preto e branco', 'srd frajola'], 'srd-gato-frajola', 'SRD'),
  cat('gato-outra', 'Outra raça', otherAliases, 'outra-raca-gato', 'OTHER'),
  cat('persa', 'Persa', ['persian']),
  cat('himalaio', 'Himalaio', ['himalaia', 'himalayan']),
  cat('exotico', 'Exótico de Pelo Curto', ['exótico', 'exotic', 'exotic shorthair', 'persa de pelo curto']),
  cat('siames', 'Siamês', ['siames', 'siamese']),
  cat('maine-coon', 'Maine Coon', ['mainecoon', 'maine', 'mei coon'], 'maine-coon', 'BREED', 'Médio'),
  cat('angora', 'Angorá Turco', ['angorá', 'angora', 'turkish angora']),
  cat('ragdoll', 'Ragdoll', ['rag doll']),
  cat('sagrado-da-birmania', 'Sagrado da Birmânia', ['birmanês', 'birman', 'sagrado', 'sagrado da birmania']),
  cat('british-shorthair', 'British Shorthair', ['british', 'britânico']),
  cat('azul-russo', 'Azul Russo', ['russian blue', 'russo']),
  cat('chartreux', 'Chartreux', ['cartuxo']),
  cat('sphynx', 'Sphynx', ['sphinx', 'esfinge', 'pelado', 'sem pelo']),
  cat('bengal', 'Bengal', ['bengala', 'bengal']),
  cat('savannah', 'Savannah', ['savana', 'savanah']),
  cat('mau-egipcio', 'Mau Egípcio', ['egyptian mau', 'mau egipcio']),
  cat('abissinio', 'Abissínio', ['abyssinian', 'abissinio']),
  cat('scottish-fold', 'Scottish Fold', ['scottish', 'fold', 'orelha dobrada']),
  cat('devon-rex', 'Devon Rex', ['devon']),
  cat('cornish-rex', 'Cornish Rex', ['cornish']),
  cat('noruegues-da-floresta', 'Norueguês da Floresta', ['norwegian forest', 'norueguês', 'noruegues da floresta']),
  cat('siberiano', 'Siberiano', ['siberian']),
  cat('american-shorthair', 'American Shorthair', ['americano de pelo curto']),
  cat('oriental', 'Oriental de Pelo Curto', ['oriental']),
  cat('bombay', 'Bombay', ['bombaim']),
  cat('munchkin', 'Munchkin', ['munchikin', 'manchkin']),
];

export const PET_BREEDS = Object.freeze(entries.map((entry) => Object.freeze({ ...entry, aliases: Object.freeze([...entry.aliases]) })));
const byCode = new Map(PET_BREEDS.map((breed) => [breed.code, breed]));

export const petBreed = (code) => (typeof code === 'string' ? byCode.get(code) ?? null : null);
export const otherBreed = (species, size) => species === 'Gato' ? byCode.get('gato-outra')
  : byCode.get(`outra-${{ Pequeno: 'pequeno', Médio: 'medio', Grande: 'grande' }[size] ?? 'medio'}`);

/// Lower case, no accents and only letters and digits separated by one space.
export function normalizeBreedText(value) {
  return String(value ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ').trim();
}
const compact = (value) => normalizeBreedText(value).replaceAll(' ', '');
const keys = new Map(PET_BREEDS.map((breed) => [breed.code, new Set([breed.name, ...breed.aliases].map(compact))]));

/// Breed of a pet saved before the list existed, by its free text. Several
/// entries with the same name (poodle, vira-lata) are told apart by the size
/// the pet already had. Null when nothing on the list has that name.
export function matchLegacyBreed(species, breed, size) {
  const key = compact(breed);
  if (!key) return null;
  const found = PET_BREEDS.filter((entry) => entry.species === species && keys.get(entry.code).has(key));
  return found.find((entry) => entry.size === size) ?? found[0] ?? null;
}
