import '../models.dart';

abstract interface class SaasRepository {
  Future<SuperAdmin> signIn(String email, String password);
  Future<List<Tenant>> getTenants();
  Future<List<Plan>> getPlans();
  Future<List<Subscription>> getSubscriptions();
  Future<List<AuditEvent>> getAuditEvents();
  Future<void> saveTenant(Tenant tenant);
  Future<void> setTenantStatus(
    String tenantId,
    TenantStatus status,
    String? reason,
  );
  Future<void> saveInitialManager(String tenantId, TenantUser manager);
  Future<void> setUserActive(String tenantId, String userId, bool active);

  /// Deletes the principal manager's account; exclusive to the SaaS.
  Future<void> deleteManagerAccount(String tenantId, String userId);
  Future<void> savePlan(Plan plan);
  Future<void> updateSubscription(
    String id,
    String planId,
    SubscriptionStatus status,
  );
}
