import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show AppointmentStatus;

import 'appointment_item.dart';
import 'customer.dart';

/// Note written by the professional during the service of one pet.
class ServiceNote {
  const ServiceNote({required this.petId, required this.text, this.createdAt});
  final String petId;
  final String text;
  final DateTime? createdAt;
}

class Appointment {
  const Appointment({
    required this.id,
    this.recordNumber,
    required this.customer,
    required this.startsAt,
    required this.status,
    required this.items,
    this.professional,
    this.professionalId,
    this.companyStartsAt,
    this.notes = '',
    this.tutorNotes = '',
    this.observations = const [],
    this.scheduleMinutes,
  });

  /// Real time of the booking: the busiest professional, with pets of
  /// different professionals done at the same time. [duration] stays the
  /// summed time of the services.
  final int? scheduleMinutes;
  int get reservedMinutes => scheduleMinutes ?? duration;

  /// Names of the professionals of the pets, or of the appointment.
  String? get professionals {
    final names = {for (final item in items) ?item.professional};
    return names.isEmpty ? professional : names.join(', ');
  }

  /// Professional notes about the service; read-only for management.
  final List<ServiceNote> observations;
  final int? recordNumber;
  final String id;
  final Customer customer;
  final DateTime startsAt;
  final AppointmentStatus status;
  final List<AppointmentItem> items;
  final String? professional;
  final String? professionalId;
  final DateTime? companyStartsAt;
  DateTime get displayStartsAt => companyStartsAt ?? startsAt;
  final String notes;

  /// Written by the tutor in the PWA; read-only for the team.
  final String tutorNotes;
  int get duration => items.fold(0, (sum, item) => sum + item.duration);
  double get price => items.fold(0, (sum, item) => sum + item.price);
  String get petNames => items.map((item) => item.pet.name).join(', ');
  Appointment copyWith({AppointmentStatus? status, String? notes}) =>
      Appointment(
        id: id,
        recordNumber: recordNumber,
        customer: customer,
        startsAt: startsAt,
        status: status ?? this.status,
        items: items,
        professional: professional,
        professionalId: professionalId,
        companyStartsAt: companyStartsAt,
        notes: notes ?? this.notes,
        tutorNotes: tutorNotes,
        observations: observations,
        scheduleMinutes: scheduleMinutes,
      );
}
