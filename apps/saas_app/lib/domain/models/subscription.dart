import 'subscription_status.dart';

class Subscription {
  const Subscription({
    required this.id,
    this.recordNumber,
    required this.tenantId,
    required this.planId,
    required this.status,
    this.startedAt,
    this.renewsAt,
    this.accountId,
  });
  final int? recordNumber;
  final String id;
  final String tenantId;
  final String planId;
  final SubscriptionStatus status;

  /// Absent while a petshop waits for its principal manager (A1-p).
  final DateTime? startedAt;

  /// Absent while a petshop is outside the paid cycle of its manager.
  final DateTime? renewsAt;

  /// Principal manager whose subscription covers this petshop (A1); null in
  /// the legacy model, one subscription per petshop.
  final String? accountId;
  bool get managed => accountId != null;

  /// After its date, a managed cycle follows the E2 phases instead of
  /// stopping at once: 7 normal days, then the pause of bookings.
  bool expiredAt(DateTime instant) =>
      managed &&
      renewsAt != null &&
      !renewsAt!.isAfter(instant) &&
      (status == SubscriptionStatus.active ||
          status == SubscriptionStatus.trial);
  bool validAt(DateTime instant) =>
      status == SubscriptionStatus.active ||
      (status == SubscriptionStatus.trial &&
          (managed || (renewsAt?.isAfter(instant) ?? false)));

  Subscription copyWith({String? planId, SubscriptionStatus? status}) =>
      Subscription(
        id: id,
        recordNumber: recordNumber,
        tenantId: tenantId,
        planId: planId ?? this.planId,
        status: status ?? this.status,
        startedAt: startedAt,
        renewsAt: renewsAt,
        accountId: accountId,
      );
}
