import '../models.dart';

/// Google as a way to prove the administrator's identity. It replaces only
/// the password: platform access and the e-mail code remain decided by the
/// backend, exactly as in the password sign-in.
abstract interface class SaasGoogleAccess {
  Future<SuperAdmin> signInWithGoogle();
  Future<void> linkGoogle();

  /// Sign-in methods of the current account: `password`, `google.com`.
  List<String> get providers;
}

/// Support requests sent by petshop managers through the Equipe app.
abstract interface class SaasSupportDesk {
  Future<List<SupportRequest>> supportRequests();
  Future<void> replySupportRequest(
    String id,
    String message, {
    required bool close,
  });
}

/// "Renovar até" (E2): exceptions such as a payment of several months or a
/// courtesy, recorded with the reason in the platform audit.
abstract interface class SaasRenewalDesk {
  Future<void> renewSubscriptionUntil(
    String tenantId,
    DateTime day,
    String reason,
  );
}

/// Subscription requests of the principal managers (A1): the platform
/// confirms the payment made outside the app and applies the change.
abstract interface class SaasBillingDesk {
  Future<BillingQueue> billingRequests();
  Future<void> decideBillingRequest(
    String id, {
    required bool approve,
    String reason = '',
  });
}
