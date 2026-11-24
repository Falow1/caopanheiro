import '../models.dart';

/// Online capabilities added after the first Equipe contract. Kept apart so
/// repositories without them (tests, catalogue-only) keep working unchanged.
abstract interface class TeamExtrasRepository {
  /// False when a wrapper has no server behind it (tests, catalogue-only).
  bool get extrasAvailable;

  /// Google proves only the identity. Links, roles and invitations are still
  /// decided by the backend, exactly as in the password sign-in.
  Future<InternalUser> signInWithGoogle();
  Future<void> linkGoogle();

  /// Sign-in methods of the current account: `password`, `google.com`.
  List<String> get signInProviders;

  /// Read scoped to the selected petshop. Requires connection.
  Future<Map<String, dynamic>> companyQuery(
    String name, [
    Map<String, dynamic> input = const {},
  ]);

  /// Confirmed write scoped to the selected petshop, with a repeatable id.
  Future<Map<String, dynamic>> companyCommand(
    String name,
    Map<String, dynamic> input,
  );
}

/// In-app notices of one role in one petshop: read when the app opens or
/// refreshes. Nothing is pushed to the device.
abstract interface class RoleNoticesSource {
  Future<Map<String, dynamic>> roleNotices(String tenantId);
  Future<void> markRoleNoticesSeen(String tenantId);
}
