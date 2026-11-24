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

class TutorSlot {
  const TutorSlot({
    required this.startsAt,
    required this.label,
    required this.professionalId,
    required this.professionalName,
  });
  final DateTime startsAt;
  final String label;
  final String professionalId;
  final String professionalName;
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
    List<Map<String, dynamic>> items,
  );
}
