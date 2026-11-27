import 'pet_breed.dart';

/// Why the petshop does not serve a pet, in the order the server checks.
enum PetServiceReason {
  blocked('PET_BLOCKED'),
  species('SPECIES_NOT_SERVED'),
  puppy('PUPPY_NOT_SERVED'),
  breed('BREED_NOT_SERVED'),
  size('SIZE_NOT_SERVED');

  const PetServiceReason(this.wire);
  final String wire;

  static PetServiceReason? fromWire(Object? value) {
    for (final reason in values) {
      if (reason.wire == value) return reason;
    }
    return null;
  }
}

/// How the petshop serves dogs: every dog, some sizes, its own list or none.
enum PetDogMode {
  all('ALL'),
  sizes('SIZES'),
  list('LIST'),
  none('NONE');

  const PetDogMode(this.wire);
  final String wire;
}

/// How the petshop serves cats: every cat, its own list or none.
enum PetCatMode {
  all('ALL'),
  list('LIST'),
  none('NONE');

  const PetCatMode(this.wire);
  final String wire;
}

/// Puppies (under 12 months): follow the rule, serve any breed or none.
enum PetPuppyRule {
  rule('RULE'),
  all('ALL'),
  none('NONE');

  const PetPuppyRule(this.wire);
  final String wire;
}

T _choice<T extends Enum>(
  List<T> values,
  Object? wire,
  T fallback,
  String Function(T) wireOf,
) {
  for (final value in values) {
    if (wireOf(value) == wire) return value;
  }
  return fallback;
}

List<String> _codes(Object? value, String species) => value is List
    ? [
        for (final code in value)
          if (code is String && PetBreeds.byCode(code)?.species == species)
            code,
      ]
    : const [];

/// Pets the petshop serves (Mais → Funcionamento → Pets atendidos). The server
/// decides; the apps use this copy to show the rule and the warnings before
/// sending. Without a saved rule the petshop serves every pet.
final class PetPolicy {
  const PetPolicy({
    this.dogMode = PetDogMode.all,
    this.dogSizes = const [],
    this.dogBreeds = const [],
    this.dogExcluded = const [],
    this.catMode = PetCatMode.all,
    this.catBreeds = const [],
    this.catExcluded = const [],
    this.puppies = PetPuppyRule.rule,
    this.version = 0,
  });

  factory PetPolicy.fromJson(Object? json) {
    if (json is! Map) return const PetPolicy();
    final dogs = json['dogs'] is Map ? json['dogs'] as Map : const {};
    final cats = json['cats'] is Map ? json['cats'] as Map : const {};
    final sizes = dogs['sizes'] is List ? dogs['sizes'] as List : const [];
    return PetPolicy(
      dogMode: _choice(
        PetDogMode.values,
        dogs['mode'],
        PetDogMode.all,
        (mode) => mode.wire,
      ),
      dogSizes: [
        for (final size in PetBreeds.sizes)
          if (sizes.contains(size)) size,
      ],
      dogBreeds: _codes(dogs['breeds'], 'Cachorro'),
      dogExcluded: _codes(dogs['excluded'], 'Cachorro'),
      catMode: _choice(
        PetCatMode.values,
        cats['mode'],
        PetCatMode.all,
        (mode) => mode.wire,
      ),
      catBreeds: _codes(cats['breeds'], 'Gato'),
      catExcluded: _codes(cats['excluded'], 'Gato'),
      puppies: _choice(
        PetPuppyRule.values,
        json['puppies'],
        PetPuppyRule.rule,
        (rule) => rule.wire,
      ),
      version: json['version'] is int ? json['version'] as int : 0,
    );
  }

  final PetDogMode dogMode;
  final List<String> dogSizes;
  final List<String> dogBreeds;
  final List<String> dogExcluded;
  final PetCatMode catMode;
  final List<String> catBreeds;
  final List<String> catExcluded;
  final PetPuppyRule puppies;
  final int version;

  /// Rule as sent to savePetPolicy (without the version).
  Map<String, Object?> toJson() => {
    'dogs': {
      'mode': dogMode.wire,
      'sizes': dogSizes,
      'breeds': dogBreeds,
      'excluded': dogExcluded,
    },
    'cats': {
      'mode': catMode.wire,
      'breeds': catBreeds,
      'excluded': catExcluded,
    },
    'puppies': puppies.wire,
  };

  PetPolicy copyWith({
    PetDogMode? dogMode,
    List<String>? dogSizes,
    List<String>? dogBreeds,
    List<String>? dogExcluded,
    PetCatMode? catMode,
    List<String>? catBreeds,
    List<String>? catExcluded,
    PetPuppyRule? puppies,
  }) => PetPolicy(
    dogMode: dogMode ?? this.dogMode,
    dogSizes: dogSizes ?? this.dogSizes,
    dogBreeds: dogBreeds ?? this.dogBreeds,
    dogExcluded: dogExcluded ?? this.dogExcluded,
    catMode: catMode ?? this.catMode,
    catBreeds: catBreeds ?? this.catBreeds,
    catExcluded: catExcluded ?? this.catExcluded,
    puppies: puppies ?? this.puppies,
    version: version,
  );

  /// Null when the petshop serves the breed, for a pet born on [birthDate].
  PetServiceReason? evaluate(
    PetBreed breed, {
    String? birthDate,
    bool blocked = false,
    DateTime? now,
  }) {
    if (blocked) return PetServiceReason.blocked;
    final cat = breed.species == 'Gato';
    if (cat ? catMode == PetCatMode.none : dogMode == PetDogMode.none) {
      return PetServiceReason.species;
    }
    final puppy = isPuppy(birthDate, now);
    if (puppy && puppies == PetPuppyRule.none) return PetServiceReason.puppy;
    if (puppy && puppies == PetPuppyRule.all) return null;
    if (cat ? catMode == PetCatMode.list : dogMode == PetDogMode.list) {
      return (cat ? catBreeds : dogBreeds).contains(breed.code)
          ? null
          : PetServiceReason.breed;
    }
    if (!cat && dogMode == PetDogMode.sizes && !dogSizes.contains(breed.size)) {
      return PetServiceReason.size;
    }
    return (cat ? catExcluded : dogExcluded).contains(breed.code)
        ? PetServiceReason.breed
        : null;
  }

  /// Breeds the petshop serves for a new pet (the birth date may still change).
  bool serves(PetBreed breed, {String? birthDate}) =>
      evaluate(breed, birthDate: birthDate) == null;
}

/// A puppy is under 12 months old, counted from the birth date (yyyy-MM-dd).
bool isPuppy(String? birthDate, [DateTime? now]) {
  if (birthDate == null ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birthDate)) {
    return false;
  }
  final today = (now ?? DateTime.now()).toUtc().toIso8601String().substring(
    0,
    10,
  );
  final year = int.parse(birthDate.substring(0, 4)) + 1;
  return today.compareTo(
        '${year.toString().padLeft(4, '0')}${birthDate.substring(4)}',
      ) <
      0;
}

/// Warning shown with a pet the petshop does not serve. The tutor never reads
/// the internal reason of a block, only that the petshop is not serving the
/// pet by the app.
String petServiceText(
  PetServiceReason reason, {
  required String petName,
  required PetBreed? breed,
  String species = 'Cachorro',
  String petshop = 'Este petshop',
  bool tutor = false,
}) => switch (reason) {
  PetServiceReason.blocked =>
    tutor
        ? '$petshop não está atendendo $petName pelo app. Fale com o petshop.'
        : '$petName está marcado como "Não atender este pet".',
  PetServiceReason.species =>
    '$petshop não atende ${(breed?.species ?? species) == 'Gato' ? 'gatos' : 'cachorros'}.',
  PetServiceReason.puppy =>
    '$petshop não atende filhotes com menos de 12 meses.',
  PetServiceReason.size =>
    '$petshop não atende cachorros de porte ${(breed?.size ?? '').toLowerCase()}.',
  PetServiceReason.breed =>
    '$petshop não atende ${breed?.kind == PetBreedKind.breed ? 'a raça ' : ''}${breed?.name ?? 'esta raça'}.',
};
