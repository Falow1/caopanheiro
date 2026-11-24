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
    String? emoji,
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
  );
}
