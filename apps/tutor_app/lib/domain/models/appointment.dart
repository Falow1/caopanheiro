import 'package:caopanheiro_contracts/caopanheiro_contracts.dart';
export 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show AppointmentStatus;

class AppointmentItem {
  const AppointmentItem({
    required this.petId,
    required this.petName,
    required this.serviceNames,
    this.serviceIds = const [],
    required this.price,
    required this.durationMinutes,
    this.execution,
  });
  final PetExecution? execution;
  final String petId;
  final String petName;
  final List<String> serviceNames;
  final List<String> serviceIds;
  final double price;
  final int durationMinutes;
}

/// Note written by the professional during the service of one pet.
class PetObservation {
  const PetObservation({required this.petId, required this.text, this.at});
  final String petId;
  final String text;
  final DateTime? at;
}

class StatusEvent {
  const StatusEvent({required this.status, required this.at});
  final AppointmentStatus status;
  final DateTime at;
}

class Appointment {
  const Appointment({
    required this.id,
    this.recordNumber,
    required this.startsAt,
    required this.status,
    required this.items,
    required this.history,
    this.companyId,
    this.companyStartsAt,
    this.professionalId,
    this.transportQuoteId,
    this.expectedServices,
    this.transport,
    this.tutorNotes = '',
    this.observations = const [],
  });

  /// Professional notes about the service, shown per pet.
  final List<PetObservation> observations;
  final List<Map<String, dynamic>>? expectedServices;
  final String? transportQuoteId;
  final Map<String, dynamic>? transport;

  /// Guidance written by the tutor; team notes live in a separate field.
  final String tutorNotes;
  int get transportFeeCents => (transport?["totalCents"] as int?) ?? 0;
  double get grandTotal => totalPrice + transportFeeCents / 100;
  final int? recordNumber;
  final String id;
  final DateTime startsAt;
  final String? companyId;
  final String? professionalId;
  final DateTime? companyStartsAt;
  DateTime get displayStartsAt => companyStartsAt ?? startsAt;
  final AppointmentStatus status;
  final List<AppointmentItem> items;
  final List<StatusEvent> history;
  double get totalPrice => items.fold(0, (sum, item) => sum + item.price);
  int get totalDuration =>
      items.fold(0, (sum, item) => sum + item.durationMinutes);
  String get petNames => items.map((item) => item.petName).join(', ');
  Appointment copyWith({
    AppointmentStatus? status,
    List<StatusEvent>? history,
  }) => Appointment(
    id: id,
    recordNumber: recordNumber,
    transportQuoteId: transportQuoteId,
    expectedServices: expectedServices,
    transport: transport,
    tutorNotes: tutorNotes,
    observations: observations,
    startsAt: startsAt,
    companyId: companyId,
    professionalId: professionalId,
    companyStartsAt: companyStartsAt,
    status: status ?? this.status,
    items: items,
    history: history ?? this.history,
  );
}
