import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetBreed, PetBreeds, PetServiceReason, petEmojiForSpecies;

class Pet {
  const Pet({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.species,
    required this.breed,
    required this.size,
    required this.birthDate,
    this.notes = '',
    this.breedCode,
    this.legacyBreed,
    this.breedPending = false,
    this.serviceReason,
    this.breedSuggestion,
    String? emoji,
  });

  /// New pet or new breed chosen from the list: name and size come from it.
  factory Pet.withBreed({
    required String id,
    int? recordNumber,
    required String name,
    required PetBreed breed,
    required DateTime birthDate,
    String notes = '',
    String? breedSuggestion,
  }) => Pet(
    id: id,
    recordNumber: recordNumber,
    name: name,
    species: breed.species,
    breed: breed.name,
    size: breed.size,
    birthDate: birthDate,
    notes: notes,
    breedCode: breed.code,
    breedSuggestion: breedSuggestion,
  );

  final int? recordNumber;
  final String id;
  final String name;
  final String species;

  /// Breed name and size from the list (the server derives both from the code).
  final String breed;
  final String size;
  final DateTime birthDate;
  final String notes;

  /// Code of the breed list; absent on pets saved before it.
  final String? breedCode;

  /// Breed typed before the list that it did not find; shown to choose again.
  final String? legacyBreed;
  final bool breedPending;

  /// Why the petshop does not serve the pet now (its rule or "Não atender
  /// este pet"); null when it does. The reason of a block is never sent here.
  final PetServiceReason? serviceReason;

  /// Name typed for "Outra raça", sent once for the platform to evaluate.
  final String? breedSuggestion;

  bool get served => serviceReason == null;
  PetBreed? get breedEntry => PetBreeds.of(
    breedCode: breedCode,
    species: species,
    breed: breed,
    size: size,
  );
  String? get breedIcon => breedEntry?.icon;
  String get emoji => petEmojiForSpecies(species);

  /// Pet saved without a new breed keeps the situation of [old]: editing the
  /// name or the notes does not change whether the petshop serves it.
  Pet keepingServiceOf(Pet? old) =>
      old == null || old.breedEntry?.code != breedEntry?.code
      ? this
      : Pet(
          id: id,
          recordNumber: recordNumber ?? old.recordNumber,
          name: name,
          species: species,
          breed: breed,
          size: size,
          birthDate: birthDate,
          notes: notes,
          breedCode: breedCode,
          legacyBreed: old.legacyBreed,
          breedPending: old.breedPending,
          serviceReason: old.serviceReason,
        );

  Pet copyWith({
    String? name,
    String? species,
    String? breed,
    String? size,
    DateTime? birthDate,
    String? notes,
    String? emoji,
  }) => Pet(
    id: id,
    recordNumber: recordNumber,
    name: name ?? this.name,
    species: species ?? this.species,
    breed: breed ?? this.breed,
    size: size ?? this.size,
    birthDate: birthDate ?? this.birthDate,
    notes: notes ?? this.notes,
    breedCode: breedCode,
    legacyBreed: legacyBreed,
    breedPending: breedPending,
    serviceReason: serviceReason,
  );
}
