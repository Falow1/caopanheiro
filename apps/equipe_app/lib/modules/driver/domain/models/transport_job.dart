import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show TransportStatus, TransportType;
import 'transport_address.dart';
import 'transport_event.dart';
import 'transport_incident.dart';
import 'transport_pet.dart';

class TransportJob {
  const TransportJob({
    required this.id,
    this.recordNumber,
    this.appointmentNumber,
    required this.tenantId,
    required this.appointmentId,
    required this.type,
    required this.scheduledAt,
    this.companyScheduledAt,
    required this.status,
    required this.origin,
    required this.destination,
    required this.pets,
    required this.notes,
    required this.events,
    this.incidents = const [],
    this.collectionChecks,
    this.deliveryChecks = const [],
    this.assignmentHistory = const [],
    this.startedAt,
    this.collectedAt,
    this.deliveredAt,
  });
  final int? recordNumber;
  final int? appointmentNumber;
  final String id;
  final String tenantId;
  final String appointmentId;
  final TransportType type;
  final DateTime scheduledAt;

  /// Wall clock of the company (its own city zone), as sent by the server.
  final DateTime? companyScheduledAt;
  DateTime get displayScheduledAt => companyScheduledAt ?? scheduledAt;
  final TransportStatus status;
  final TransportAddress origin;
  final TransportAddress destination;
  final List<TransportPet> pets;
  final String notes;
  final List<TransportEvent> events;
  final List<TransportIncident> incidents;
  final List<TransportPetCheck>? collectionChecks;
  final List<TransportPetCheck> deliveryChecks;
  final List<String> assignmentHistory;
  String petIdAt(int index) =>
      pets[index].id.isEmpty ? 'legacy-$index' : pets[index].id;

  final DateTime? startedAt;
  final DateTime? collectedAt;
  final DateTime? deliveredAt;
  String get petsLabel => pets.map((pet) => pet.name).join(', ');

  TransportJob copyWith({
    TransportStatus? status,
    List<TransportEvent>? events,
    List<TransportIncident>? incidents,
    List<TransportPetCheck>? collectionChecks,
    List<TransportPetCheck>? deliveryChecks,
    DateTime? startedAt,
    DateTime? collectedAt,
    DateTime? deliveredAt,
  }) => TransportJob(
    id: id,
    recordNumber: recordNumber,
    appointmentNumber: appointmentNumber,
    tenantId: tenantId,
    appointmentId: appointmentId,
    type: type,
    scheduledAt: scheduledAt,
    companyScheduledAt: companyScheduledAt,
    status: status ?? this.status,
    origin: origin,
    destination: destination,
    pets: pets,
    notes: notes,
    events: events ?? this.events,
    incidents: incidents ?? this.incidents,
    collectionChecks: collectionChecks ?? this.collectionChecks,
    deliveryChecks: deliveryChecks ?? this.deliveryChecks,
    assignmentHistory: assignmentHistory,
    startedAt: startedAt ?? this.startedAt,
    collectedAt: collectedAt ?? this.collectedAt,
    deliveredAt: deliveredAt ?? this.deliveredAt,
  );
}
