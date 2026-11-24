import '../../../domain/models.dart';

List<Tenant> searchSupportTenants(List<Tenant> tenants, String query) =>
    tenants.where((item) {
      final value = query.toLowerCase();
      return item.name.toLowerCase().contains(value) ||
          item.id.toLowerCase().contains(value) ||
          item.responsible.toLowerCase().contains(value);
    }).toList();

bool isTenantOperational(Tenant tenant) =>
    tenant.status != TenantStatus.suspended;

bool isSubscriptionOperational(SubscriptionStatus status) => const [
  SubscriptionStatus.active,
  SubscriptionStatus.trial,
].contains(status);

bool hasActiveManager(Tenant tenant) =>
    tenant.users.any((item) => item.role == TenantRole.manager && item.active);

bool hasServices(Tenant tenant) => tenant.metrics.services > 0;

bool hasProfessionals(Tenant tenant) => tenant.metrics.professionals > 0;

bool hasConfiguredSchedule(Tenant tenant) => tenant.onboarding[2].completed;
