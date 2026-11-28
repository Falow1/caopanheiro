import 'dart:async';

import 'package:caopanheiro_core/caopanheiro_core.dart';

import '../domain/repositories/saas_session.dart';
import '../domain/repositories/saas_administration.dart';
import '../domain/repositories/saas_extras.dart';

import '../domain/models.dart';
import '../domain/repositories/saas_repository.dart';

class AppController extends AppControllerBase with LiveFollowing {
  AppController(this._repository);
  final SaasRepository _repository;
  int _epoch = 0;
  SaasSession? get _session =>
      _repository is SaasSession ? _repository as SaasSession : null;
  SaasAdministration? get _administration => _repository is SaasAdministration
      ? _repository as SaasAdministration
      : null;
  bool get requiresEmailCode => _administration?.requiresEmailCode ?? false;
  SaasDemoAdministration? get _demoAdministration =>
      _repository is SaasDemoAdministration
      ? _repository as SaasDemoAdministration
      : null;
  bool get canSkipEmailCode => _demoAdministration?.canSkipEmailCode ?? false;
  SaasGoogleAccess? get _google =>
      _repository is SaasGoogleAccess ? _repository as SaasGoogleAccess : null;
  SaasSupportDesk? get _desk =>
      _repository is SaasSupportDesk ? _repository as SaasSupportDesk : null;

  /// Google replaces only the password; access is still decided by the server.
  bool get googleAvailable => _google != null;
  List<String> get providers => _google?.providers ?? const [];
  Future<bool> signInWithGoogle() => _guard(() async {
    final google = _google;
    if (google == null) return;
    final epoch = _epoch;
    final admin = await google.signInWithGoogle();
    if (epoch != _epoch) return;
    _admin = admin;
    await _reload();
  });
  Future<bool> linkGoogle() => _guard(() async {
    await _google?.linkGoogle();
    notifyListeners();
  });

  bool get supportDeskAvailable => _desk != null;

  /// "Renovar até" (E2), for exceptions; the reason goes to the audit.
  Future<bool> renewSubscriptionUntil(
    String tenantId,
    DateTime day,
    String reason,
  ) => _mutation(() async {
    final Object repository = _repository;
    if (repository is! SaasRenewalDesk) {
      throw const FormatException(
        'Renovação disponível somente na integração.',
      );
    }
    await repository.renewSubscriptionUntil(tenantId, day, reason);
  });

  SaasBreedSuggestions? get _breeds => _repository is SaasBreedSuggestions
      ? _repository as SaasBreedSuggestions
      : null;
  bool get breedSuggestionsAvailable => _breeds != null;
  List<BreedSuggestion> _breedSuggestions = const [];

  /// Most typed first.
  List<BreedSuggestion> get breedSuggestions => _breedSuggestions;
  Future<bool> loadBreedSuggestions() => _guard(() async {
    final breeds = _breeds;
    if (breeds == null) return;
    final epoch = _epoch;
    final rows = [...await breeds.breedSuggestions()]
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0
            ? byCount
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    if (epoch == _epoch) _breedSuggestions = rows;
  });

  /// "Avaliada": the suggestion leaves the list (the breed may come in a
  /// new version of the list, or not).
  Future<bool> removeBreedSuggestion(String id) => _guard(() async {
    final breeds = _breeds;
    if (breeds == null) return;
    if (readOnly) {
      throw const FormatException(
        'Atualize os dados antes de fazer outra alteração.',
      );
    }
    final epoch = _epoch;
    await breeds.removeBreedSuggestion(id);
    if (epoch == _epoch) {
      _breedSuggestions = [
        for (final item in _breedSuggestions)
          if (item.id != id) item,
      ];
    }
  });

  SaasBillingDesk? get _billing =>
      _repository is SaasBillingDesk ? _repository as SaasBillingDesk : null;
  BillingQueue _billingQueue = const BillingQueue();

  /// Pending items of the platform (A1-s), read with every refresh; empty on
  /// a server before the A1.
  BillingQueue get billingQueue => _billingQueue;

  /// Support requests waiting for an answer: from the list once it was read,
  /// otherwise the count that comes with the pending items.
  int get supportWaitingCount =>
      _supportLoaded ? waitingSupportRequests : _billingQueue.supportWaiting;

  /// The platform confirms the payment made outside the app (or registers
  /// the refund) and the server applies the change.
  Future<bool> decideBillingRequest(
    String id, {
    required bool approve,
    String reason = '',
  }) => _mutation(() async {
    final desk = _billing;
    if (desk == null) {
      throw const FormatException(
        'Pendências disponíveis somente na integração.',
      );
    }
    await desk.decideBillingRequest(id, approve: approve, reason: reason);
  });

  Future<void> _loadBilling() async {
    final desk = _billing;
    if (desk == null || requiresEmailCode) {
      _billingQueue = const BillingQueue();
      return;
    }
    final epoch = _epoch;
    try {
      final queue = await desk.billingRequests();
      if (epoch == _epoch) _billingQueue = queue;
    } on SessionAccessException {
      rethrow;
    } catch (_) {
      // The pending items are a hint: the last ones stay until the next read.
    }
  }

  List<SupportRequest> _supportRequests = const [];

  /// The support list was read in this session, even if it came back empty:
  /// from then on the live refresh keeps it current.
  bool _supportLoaded = false;
  List<SupportRequest> get supportRequests => _supportRequests;
  bool get supportLoaded => _supportLoaded;
  int get waitingSupportRequests =>
      _supportRequests.where((request) => request.waiting).length;
  Future<bool> loadSupportRequests() => _guard(() async {
    final desk = _desk;
    if (desk == null) return;
    final epoch = _epoch;
    final rows = await desk.supportRequests();
    if (epoch != _epoch) return;
    _supportRequests = rows;
    _supportLoaded = true;
  });
  Future<bool> replySupportRequest(
    String id,
    String message, {
    required bool close,
  }) => _guard(() async {
    final desk = _desk;
    if (desk == null) {
      throw const FormatException('Suporte disponível somente na integração.');
    }
    if (readOnly) {
      throw const FormatException(
        'Atualize os dados antes de fazer outra alteração.',
      );
    }
    final epoch = _epoch;
    await desk.replySupportRequest(id, message, close: close);
    if (epoch != _epoch) return;
    // Confirmed reply: a failed reload must not look like a failed answer.
    try {
      final rows = await desk.supportRequests();
      if (epoch == _epoch) _supportRequests = rows;
    } on NetworkException {
      _refreshWarning =
          'Resposta enviada. Não foi possível atualizar a consulta. '
          'Atualize os dados para conferir o resultado e continuar editando.';
    }
  });
  PlatformHealth? _health;
  SupportDiagnostic? _diagnostic;
  PlatformHealth? get health => _health;
  SupportDiagnostic? get diagnostic => _diagnostic;
  SaasAdministration get _operations =>
      _administration ??
      (throw const FormatException(
        'Operação disponível somente na integração.',
      ));
  Future<bool> requestEmailCode() => _guard(() async {
    await _operations.requestEmailCode();
  });
  Future<bool> verifyEmailCode(String code) =>
      _confirmEmailSession(() => _operations.verifyEmailCode(code));

  Future<bool> skipDemoEmailCode() {
    final demo = _demoAdministration;
    if (demo == null || !demo.canSkipEmailCode) return Future.value(false);
    return _confirmEmailSession(demo.skipDemoEmailCode);
  }

  Future<bool> _confirmEmailSession(Future<SuperAdmin> Function() confirm) =>
      _guard(() async {
        final epoch = _epoch;
        final admin = await confirm();
        if (epoch != _epoch) return;
        _admin = admin;
        await _reload();
      });
  Future<bool> changePassword(String current, String password) async {
    final success = await _guard(
      () => _operations.changePassword(current, password),
    );
    if (success || _administration?.authenticated == false) signOut();
    return success;
  }

  Future<bool> loadHealth() => _guard(() async {
    final epoch = _epoch;
    final result = await _operations.health();
    if (epoch == _epoch) _health = result;
  });
  Future<bool> diagnose(String tenantId, String reason) => _guard(() async {
    _diagnostic = null;
    final epoch = _epoch;
    final result = await _operations.diagnose(tenantId, reason);
    if (epoch == _epoch) {
      _diagnostic = result;
      await _refreshAfterConfirmation(epoch);
    }
  });
  bool get integrated => _session != null;
  String? _refreshWarning;
  String? get refreshWarning => _refreshWarning;
  bool get readOnly => _refreshWarning != null || (_session?.readOnly ?? false);

  @override
  Object? get networkProblemSource => _repository;
  DateTime? get updatedAt => _session?.updatedAt;
  String? get cacheWarning => _refreshWarning ?? _session?.cacheWarning;
  Future<void> restoreSession() async {
    final session = _session;
    if (session == null) return;
    try {
      _admin = await session.restore();
    } on SessionAccessException catch (refused) {
      // Offline copy past its limit, already erased: the reason stays on the
      // login.
      await runGuarded(() async => throw refused);
      return;
    }
    if (_admin != null) await refresh();
  }

  Future<bool> refresh() => _guard(() async {
    final epoch = _epoch;
    await _reload();
    if (epoch == _epoch) _refreshWarning = null;
  });

  /// Live refresh: the server moved the platform signal, watched once the
  /// e-mail code was confirmed. Companies, plans, subscriptions, audit and
  /// the support list, once read in this session, are read again without
  /// loading state; a failure waits for the next signal.
  @override
  LiveSignalSource? get liveSource => _repository is LiveSignalsAware
      ? (_repository as LiveSignalsAware).liveSignals
      : null;
  @override
  Iterable<String> livePaths(String uid) => _admin == null || requiresEmailCode
      ? const []
      : const [LiveSignalPaths.platform];

  @override
  Future<void> liveReload() async {
    final epoch = _epoch;
    await _reload();
    if (epoch != _epoch) return;
    _refreshWarning = null;
    final desk = _desk;
    if (desk != null && _supportLoaded) {
      final rows = await desk.supportRequests();
      if (epoch == _epoch) _supportRequests = rows;
    }
  }

  Future<bool> _mutation(Future<void> Function() write) => _guard(() async {
    if (readOnly) {
      throw const FormatException(
        'Atualize os dados antes de fazer outra alteração.',
      );
    }
    final epoch = _epoch;
    await write();
    if (epoch != _epoch) return;
    await _refreshAfterConfirmation(epoch);
  });

  Future<void> _refreshAfterConfirmation(int epoch) async {
    try {
      await _reload();
      if (epoch == _epoch) _refreshWarning = null;
    } on SessionAccessException {
      rethrow;
    } on SessionChangedException {
      rethrow;
    } catch (_) {
      if (epoch == _epoch) {
        _refreshWarning =
            'Alteração salva. Não foi possível atualizar a consulta. '
            'Atualize os dados para conferir o resultado e continuar editando.';
      }
    }
  }

  Future<bool> _guard(Future<void> Function() action) async {
    final epoch = _epoch;
    final success = await runGuarded(() async {
      try {
        await action();
      } on SessionAccessException {
        if (epoch == _epoch) _endRefusedAccess();
        rethrow;
      }
    });
    if (epoch != _epoch) {
      clearOperationState();
      return false;
    }
    return success;
  }

  /// Refused before anyone entered (wrong password, account without
  /// administrative access): only the partial sign-in ends, and the reason
  /// stays on the login. With an administrator inside, the session ends.
  void _endRefusedAccess() {
    if (_admin != null) return signOut();
    final session = _session;
    if (session != null) unawaited(session.signOut().catchError((Object _) {}));
  }

  Future<bool> saveMember(
    String tenantId,
    String name,
    String email,
    String role,
  ) => _mutation(() async {
    final session = _session;
    if (session == null) {
      throw const FormatException('Vínculo disponível no modo integrado.');
    }
    await session.saveMember(tenantId, name, email, role);
  });

  SuperAdmin? _admin;
  List<Tenant> _tenants = const [];
  List<Plan> _plans = const [];
  List<Subscription> _subscriptions = const [];
  List<AuditEvent> _auditEvents = const [];

  SuperAdmin? get admin => _admin;
  List<Tenant> get tenants => _tenants;
  List<Plan> get plans => _plans;
  List<Subscription> get subscriptions => _subscriptions;
  List<AuditEvent> get auditEvents => _auditEvents;

  Future<bool> signIn(String email, String password) => _guard(() async {
    final epoch = _epoch;
    final admin = await _repository.signIn(email, password);
    if (epoch != _epoch) return;
    _admin = admin;
    await _reload();
  });

  void signOut() {
    ++_epoch;
    final session = _session;
    if (session != null) unawaited(session.signOut().catchError((Object _) {}));
    _admin = null;
    _refreshWarning = null;
    _health = null;
    _diagnostic = null;
    _supportRequests = const [];
    _breedSuggestions = const [];
    _billingQueue = const BillingQueue();
    _supportLoaded = false;
    _tenants = const [];
    _plans = const [];
    _subscriptions = const [];
    _auditEvents = const [];
    clearOperationState(notify: false);
    notifyListeners();
  }

  Future<bool> saveTenant(Tenant tenant) => _mutation(() async {
    await _repository.saveTenant(tenant);
  });

  Future<bool> setTenantStatus(
    String id,
    TenantStatus status, [
    String? reason,
  ]) => _mutation(() async {
    await _repository.setTenantStatus(id, status, reason);
  });

  Future<bool> saveInitialManager(String id, TenantUser manager) =>
      _mutation(() async {
        await _repository.saveInitialManager(id, manager);
      });

  Future<bool> setUserActive(String tenantId, String userId, bool active) =>
      _mutation(() async {
        await _repository.setUserActive(tenantId, userId, active);
      });

  Future<bool> deleteManagerAccount(String tenantId, String userId) =>
      _mutation(() async {
        await _repository.deleteManagerAccount(tenantId, userId);
      });

  Future<bool> savePlan(Plan plan) => _mutation(() async {
    await _repository.savePlan(plan);
  });

  Future<bool> updateSubscription(
    String id,
    String planId,
    SubscriptionStatus status,
  ) => _mutation(() async {
    await _repository.updateSubscription(id, planId, status);
  });

  Tenant tenantById(String id) => _tenants.firstWhere((item) => item.id == id);
  Plan planById(String id) => _plans.firstWhere((item) => item.id == id);
  Subscription subscriptionForTenant(String id) =>
      _subscriptions.firstWhere((item) => item.tenantId == id);

  Future<void> _reload() async {
    if (requiresEmailCode) {
      _tenants = const [];
      _plans = const [];
      _subscriptions = const [];
      _auditEvents = const [];
      return;
    }
    final epoch = _epoch;
    final values = await Future.wait([
      _repository.getTenants(),
      _repository.getPlans(),
      _repository.getSubscriptions(),
      _repository.getAuditEvents(),
    ]);
    if (epoch != _epoch) return;
    _tenants = values[0] as List<Tenant>;
    _plans = values[1] as List<Plan>;
    _subscriptions = values[2] as List<Subscription>;
    _auditEvents = values[3] as List<AuditEvent>;
    await _loadBilling();
  }
}
