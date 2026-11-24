import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show petEmojiForSpecies;

class Pet {
  const Pet({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.breed,
    required this.size,
    this.notes = '',
    this.species = '',
    String? emoji,
  });

  final int? recordNumber;
  final String id;
  final String name;
  final String breed;
  final String size;
  final String notes;
  final String species;
  String get emoji => petEmojiForSpecies(species);
}
