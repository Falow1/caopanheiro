import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show petEmojiForSpecies;

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
  });
  final int? recordNumber;
  final String id;
  final String name;
  final String species;
  final String breed;
  final String size;
  final DateTime birthDate;
  final String notes;
  String get emoji => petEmojiForSpecies(species);
}
