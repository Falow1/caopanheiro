import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetBreed, PetBreeds, PetServiceReason, petEmojiForSpecies;

/// "Não atender este pet": the internal reason, read only by the team.
class PetBlock {
  const PetBlock({required this.reason, this.createdAt, this.createdByName});
  final String reason;
  final DateTime? createdAt;
  final String? createdByName;
}

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
    this.block,
    this.breedSuggestion,
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
  final String? breedCode;

  /// Text of a pet saved before the list that was not found on it.
  final String? legacyBreed;

  /// Converted to "Outra raça": ask for the breed on the next edit.
  final bool breedPending;

  /// Null when the petshop serves the pet.
  final PetServiceReason? serviceReason;
  final PetBlock? block;

  /// Breed someone did not find on the list; sent once, never stored here.
  final String? breedSuggestion;

  bool get served => serviceReason == null;

  /// Entry of the list, also for copies saved before the list (old
  /// appointments), found by their text.
  PetBreed? get breedEntry => PetBreeds.of(
    breedCode: breedCode,
    species: species,
    breed: breed,
    size: size,
  );

  /// Icon of the breed in the visual package; null shows the paw.
  String? get breedIcon => breedEntry?.icon;
  String get emoji => petEmojiForSpecies(species);
}
