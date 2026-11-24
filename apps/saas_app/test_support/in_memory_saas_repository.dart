import 'in_memory/fixtures/saas_fixtures.dart';
import 'package:saas_app/domain/models.dart';
import 'package:saas_app/domain/repositories/saas_repository.dart';

class InMemorySaasRepository implements SaasRepository {
  final _admin = createInitialAdmin();

  final List<Plan> _plans = createInitialPlans();

  late final List<Tenant> _tenants = createInitialTenants();

  late final List<Subscription> _subscriptions = createInitialSubscriptions();

  final List<AuditEvent> _events = createInitialAuditEvents();

  Future<void> _wait() =>
      Future<void>.delayed(const Duration(milliseconds: 240));
  void _audit(String action, String entity, String? tenantId) => _events.insert(
    0,
    AuditEvent(
      id: 'ev${DateTime.now().microsecondsSinceEpoch}',
      action: action,
      admin: _admin.name,
      createdAt: DateTime.now(),
      entity: entity,
      result: 'Sucesso',
      tenantId: tenantId,
    ),
  );

  @override
  Future<SuperAdmin> signIn(String email, String password) async {
    await _wait();
    if (!email.contains('@') || password.length < 6) {
      throw const FormatException('Credenciais administrativas inválidas.');
    }
    return _admin;
  }

  @override
  Future<List<Tenant>> getTenants() async {
    await _wait();
    return List.unmodifiable(_tenants);
  }

  @override
  Future<List<Plan>> getPlans() async {
    await _wait();
    return List.unmodifiable(_plans);
  }

  @override
  Future<List<Subscription>> getSubscriptions() async {
    await _wait();
    return List.unmodifiable(_subscriptions);
  }

  @override
  Future<List<AuditEvent>> getAuditEvents() async {
    await _wait();
    return List.unmodifiable(_events);
  }

  @override
  Future<void> saveTenant(Tenant tenant) async {
    await _wait();
    final index = _tenants.indexWhere((item) => item.id == tenant.id);
    if (index < 0) {
      _tenants.add(tenant);
      _subscriptions.add(
        Subscription(
          id: 'sub${DateTime.now().microsecondsSinceEpoch}',
          tenantId: tenant.id,
          planId: tenant.planId,
          status: SubscriptionStatus.trial,
          startedAt: DateTime.now(),
          renewsAt: DateTime.now().add(const Duration(days: 14)),
        ),
      );
      _audit('Empresa criada', 'Tenant', tenant.id);
    } else {
      _tenants[index] = tenant;
      _audit('Empresa atualizada', 'Tenant', tenant.id);
    }
  }

  @override
  Future<void> setTenantStatus(
    String tenantId,
    TenantStatus status,
    String? reason,
  ) async {
    await _wait();
    final index = _tenants.indexWhere((item) => item.id == tenantId);
    _tenants[index] = _tenants[index].copyWith(status: status);
    _audit(
      status == TenantStatus.suspended
          ? 'Tenant suspenso${reason?.isNotEmpty == true ? ': $reason' : ''}'
          : 'Tenant reativado',
      'Tenant',
      tenantId,
    );
  }

  @override
  Future<void> saveInitialManager(String tenantId, TenantUser manager) async {
    await _wait();
    final index = _tenants.indexWhere((item) => item.id == tenantId);
    final tenant = _tenants[index];
    final steps = [...tenant.onboarding];
    steps[1] = const OnboardingStep('Gestor cadastrado', true);
    _tenants[index] = tenant.copyWith(
      responsible: manager.name,
      users: [...tenant.users, manager],
      onboarding: steps,
    );
    _audit('Gestor inicial criado', 'Usuário', tenantId);
  }

  @override
  Future<void> setUserActive(
    String tenantId,
    String userId,
    bool active,
  ) async {
    await _wait();
    final index = _tenants.indexWhere((item) => item.id == tenantId);
    final tenant = _tenants[index];
    _tenants[index] = tenant.copyWith(
      users: tenant.users
          .map(
            (user) => user.id == userId ? user.copyWith(active: active) : user,
          )
          .toList(),
    );
    _audit(
      active ? 'Usuário reativado' : 'Usuário desativado',
      'Usuário',
      tenantId,
    );
  }

  @override
  Future<void> deleteManagerAccount(String tenantId, String userId) async {
    await _wait();
    final index = _tenants.indexWhere((item) => item.id == tenantId);
    final tenant = _tenants[index];
    if (!tenant.users.any(
      (user) => user.id == userId && (user.principal || user.deletionPending),
    )) {
      throw const FormatException(
        'Esta conta não é de gestor principal deste petshop.',
      );
    }
    _tenants[index] = tenant.copyWith(
      users: tenant.users.where((user) => user.id != userId).toList(),
    );
    _audit('Conta do gestor principal excluída', 'Usuário', tenantId);
  }

  @override
  Future<void> savePlan(Plan plan) async {
    await _wait();
    final index = _plans.indexWhere((item) => item.id == plan.id);
    if (index < 0) {
      _plans.add(plan);
    } else {
      _plans[index] = plan;
    }
    _audit(index < 0 ? 'Plano criado' : 'Plano atualizado', 'Plano', null);
  }

  @override
  Future<void> updateSubscription(
    String id,
    String planId,
    SubscriptionStatus status,
  ) async {
    await _wait();
    final index = _subscriptions.indexWhere((item) => item.id == id);
    final old = _subscriptions[index];
    _subscriptions[index] = old.copyWith(planId: planId, status: status);
    final tenantIndex = _tenants.indexWhere((item) => item.id == old.tenantId);
    _tenants[tenantIndex] = _tenants[tenantIndex].copyWith(planId: planId);
    _audit(
      status == SubscriptionStatus.cancelled
          ? 'Assinatura cancelada'
          : 'Plano alterado',
      'Assinatura',
      old.tenantId,
    );
  }
}
