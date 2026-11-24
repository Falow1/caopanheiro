import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show petEmojiForSpecies;
import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show AppointmentStatus;

class TransportPet {
  const TransportPet({
    this.id = '',
    this.recordNumber,
    this.species = '',
    this.serviceStatus,
    required this.name,
    required this.breed,
    required this.size,
  });
  final AppointmentStatus? serviceStatus;
  final int? recordNumber;
  final String id;
  final String species;
  String get emoji => petEmojiForSpecies(species);
  final String name;
  final String breed;
  final String size;
}

class TransportPetCheck {
  const TransportPetCheck(this.petId, this.confirmed, this.reason);
  final String petId;
  final bool confirmed;
  final String reason;
}
