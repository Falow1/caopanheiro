import '../../../domain/models.dart';

({
  int active,
  int trial,
  int suspended,
  int users,
  int appointments,
  List<Tenant> recent,
  List<Tenant> attention,
})
dashboardSummary(List<Tenant> tenants, List<Subscription> subscriptions) {
  final active = tenants
      .where((item) => item.status == TenantStatus.active)
      .length;
  final trial = subscriptions
      .where((item) => item.status == SubscriptionStatus.trial)
      .length;
  final suspended = tenants
      .where((item) => item.status == TenantStatus.suspended)
      .length;
  final users = tenants.fold<int>(0, (sum, item) => sum + item.users.length);
  final appointments = tenants.fold<int>(
    0,
    (sum, item) => sum + item.metrics.monthlyAppointments,
  );
  final recent = [...tenants]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final attention = tenants
      .where(
        (item) =>
            item.status == TenantStatus.suspended ||
            item.onboardingDone < item.onboarding.length,
      )
      .toList();
  return (
    active: active,
    trial: trial,
    suspended: suspended,
    users: users,
    appointments: appointments,
    recent: recent,
    attention: attention,
  );
}
