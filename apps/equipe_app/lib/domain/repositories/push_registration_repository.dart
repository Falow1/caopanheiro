/// Push notifications of the team app on this device, for the signed-in
/// person. The device leaves the list at the sign out.
abstract interface class PushRegistrationRepository {
  /// Asks the permission to notify, once, and sends this device to the
  /// server. Does nothing where push is not available.
  Future<void> registerPush();
}
