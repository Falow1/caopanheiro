import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show AppointmentStatus, PetExecution;

import 'pet.dart';
import 'service_item.dart';
import 'service_observation.dart';

class Appointment {
  const Appointment({
    required this.id,
    this.recordNumber,
    required this.startsAt,
    required this.pet,
    required this.services,
    required this.status,
    required this.tutorName,
    this.observations = const [],
    this.execution,
    this.notes = '',
    this.tutorNotes = '',
    this.companyStartsAt,
  });

  final int? recordNumber;
  final String id;
  final DateTime startsAt;
  final DateTime? companyStartsAt;
  DateTime get displayStartsAt => companyStartsAt ?? startsAt;
  final PetExecution? execution;
  final String notes;
  final String tutorNotes;
  final Pet pet;
  final List<ServiceItem> services;
  final AppointmentStatus status;
  final String tutorName;
  final List<ServiceObservation> observations;

  int get totalDuration =>
      services.fold(0, (sum, service) => sum + service.durationMinutes);

  Appointment copyWith({
    AppointmentStatus? status,
    List<ServiceObservation>? observations,
  }) {
    return Appointment(
      id: id,
      recordNumber: recordNumber,
      startsAt: startsAt,
      companyStartsAt: companyStartsAt,
      pet: pet,
      execution: execution,
      notes: notes,
      tutorNotes: tutorNotes,
      services: services,
      status: status ?? this.status,
      tutorName: tutorName,
      observations: observations ?? this.observations,
    );
  }
}
