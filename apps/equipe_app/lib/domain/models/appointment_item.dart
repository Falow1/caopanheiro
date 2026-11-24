import 'package:caopanheiro_contracts/caopanheiro_contracts.dart';
import 'pet.dart';
import 'pet_service.dart';

class AppointmentItem {
  const AppointmentItem({
    required this.pet,
    required this.services,
    this.execution,
  });
  final PetExecution? execution;
  final Pet pet;
  final List<PetService> services;
  int get duration => services.fold(0, (sum, item) => sum + item.duration);
  double get price => services.fold(0, (sum, item) => sum + item.price);
}
