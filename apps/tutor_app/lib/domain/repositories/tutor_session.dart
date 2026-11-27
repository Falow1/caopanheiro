import '../models/tutor.dart';

class TutorCompany {
  const TutorCompany(
    this.id,
    this.name, {
    this.readOnly = false,
    this.contactPhone = '',
    this.bookingPaused = false,
    this.bookingNoticeFrom,
  });
  final String id;
  final String name;

  /// The petshop is not taking bookings through the app (A1-u): reading only.
  final bool readOnly;

  /// Phone of the petshop, shown to the tutor of a read-only petshop.
  final String contactPhone;

  /// New bookings and rescheduling through the app are paused (E2); the rest
  /// still works. The tutor books by phone. The reason is never shown.
  final bool bookingPaused;

  /// From this day the petshop may stop taking bookings through the app (E2).
  final DateTime? bookingNoticeFrom;
}

/// The pet of a booking and who does it, from [startsAt] to [endsAt].
class SlotAssignment {
  const SlotAssignment({
    required this.petId,
    required this.professionalId,
    required this.professionalName,
    required this.startsAt,
    required this.endsAt,
  });
  final String petId;
  final String professionalId;
  final String professionalName;
  final DateTime startsAt;
  final DateTime endsAt;
}

/// A professional free at the start of a slot, for [freeMinutes] in a row
/// (capped at the summed time of the services).
class SlotProfessional {
  const SlotProfessional(this.id, this.name, this.freeMinutes);
  final String id;
  final String name;
  final int freeMinutes;
}

/// A start time. With the distribution of the pets, [assignments] is the
/// automatic one, [minutes] the real time of the booking (the busiest
/// professional) and [professionals] who is free to be chosen per pet;
/// [professionalId] is the professional of the first pet.
class TutorSlot {
  const TutorSlot({
    required this.startsAt,
    required this.label,
    required this.professionalId,
    required this.professionalName,
    this.endsAt,
    this.minutes,
    this.assignments = const [],
    this.professionals = const [],
  });
  final DateTime startsAt;
  final String label;
  final String professionalId;
  final String professionalName;
  final DateTime? endsAt;
  final int? minutes;
  final List<SlotAssignment> assignments;
  final List<SlotProfessional> professionals;
}

/// How the pets of a booking go to the professionals: the server chooses
/// (ANY) or the tutor chooses per pet (SPECIFIC).
abstract final class Distribution {
  static const any = 'ANY';
  static const specific = 'SPECIFIC';
}

/// Answer of an accepted invite. The petshop's fixed link may only register a
/// return request: the person was unlinked there before and the principal
/// manager decides.
enum TutorLinkResult { linked, pending }

abstract interface class TutorSession {
  List<TutorCompany> get companies;
  String? get selectedCompanyId;
  bool get emailVerified;
  Future<Tutor?> restore();
  Future<Tutor> selectCompany(String id);
  Future<Tutor> refreshContext();
  Future<TutorLinkResult> acceptLink(String code);

  /// False when the account itself lacks the name or phone that the fixed
  /// link needs to create the petshop record.
  bool get accountContactComplete;

  /// Saves name and phone in the account (not in any petshop record).
  Future<Tutor> saveAccountContact(String name, String phone);
  Future<void> sendVerification();
  Future<void> sendPasswordReset(String email);
  Future<Tutor> signInWithGoogle();
  Future<void> linkGoogle();

  /// Sign-in methods of the current account: `password`, `google.com`.
  List<String> get providers;

  /// Name of the petshop whose link disappeared in the last refresh, if any.
  String? takeRemovedCompany();
  Future<void> signOut();
  Future<List<TutorSlot>> availableSlots(
    String day,
    List<Map<String, dynamic>> items, {
    String? distribution,
  });
}
