import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetBreeds, petEmojiForSpecies;

class Pet {
  const Pet({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.breed,
    required this.size,
    this.notes = '',
    this.species = '',
    this.breedCode,
    String? emoji,
  });

  final int? recordNumber;
  final String id;
  final String name;
  final String breed;
  final String size;
  final String notes;
  final String species;
  final String? breedCode;
  String get emoji => petEmojiForSpecies(species);

  /// Icon of the breed; older appointments only have the breed as text.
  String? get breedIcon => PetBreeds.of(
    breedCode: breedCode,
    species: species,
    breed: breed,
    size: size,
  )?.icon;
}
