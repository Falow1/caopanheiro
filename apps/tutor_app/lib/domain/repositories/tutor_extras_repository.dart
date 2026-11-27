import 'tutor_session.dart';

/// Page of in-app notices as sent by the server, newest first.
class TutorNoticePage {
  const TutorNoticePage(this.items, this.unread);
  final List<Map<String, dynamic>> items;
  final int unread;
}

/// Online capabilities added after the first Tutor contract. Kept apart from
/// [TutorSession] so repositories without them keep working unchanged.
abstract interface class TutorExtrasRepository {
  /// Notices are read when the app opens or refreshes; nothing is pushed.
  Future<TutorNoticePage> notices();
  Future<void> markNoticesSeen();

  /// Slots for moving an existing appointment; its own reservation is ignored.
  Future<List<TutorSlot>> rescheduleSlots(
    String day,
    List<Map<String, dynamic>> items,
    String appointmentId, {
    String? distribution,
  });

  /// Asks for pickup/return on an appointment that already exists.
  Future<void> requestTransport(String appointmentId, String quoteId);

  /// Names of linked petshops paused by the platform (suspended company or
  /// invalid subscription). The link still exists.
  List<String> get pausedCompanies;

  /// Principal manager account: only the SaaS can delete it, so the app does
  /// not offer the holder's own deletion.
  bool get principalManager;
}
