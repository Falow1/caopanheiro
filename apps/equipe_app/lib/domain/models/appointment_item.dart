import 'package:caopanheiro_contracts/caopanheiro_contracts.dart';
import 'pet.dart';
import 'pet_service.dart';

class AppointmentItem {
  const AppointmentItem({
    required this.pet,
    required this.services,
    this.execution,
    this.professional,
    this.professionalId,
    this.startsAt,
    this.companyStartsAt,
  });
  final PetExecution? execution;

  /// Who does this pet and when, as the booking distributed the pets; null
  /// in appointments saved before the distribution (one professional).
  final String? professional;
  final String? professionalId;
  final DateTime? startsAt;
  final DateTime? companyStartsAt;
  final Pet pet;
  final List<PetService> services;
  int get duration => services.fold(0, (sum, item) => sum + item.duration);
  double get price => services.fold(0, (sum, item) => sum + item.price);
}
