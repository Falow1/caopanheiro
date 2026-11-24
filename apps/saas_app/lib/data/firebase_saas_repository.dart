import 'package:caopanheiro_core/caopanheiro_core.dart';

import '../domain/models.dart';
import '../domain/repositories/saas_repository.dart';
import '../domain/repositories/saas_session.dart';
import '../domain/repositories/saas_administration.dart';
import '../domain/repositories/saas_extras.dart';

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);
DateTime _date(dynamic value) => DateTime.parse(value as String).toLocal();

TenantMetrics _metrics(dynamic value) {
  if (value == null) {
    return const TenantMetrics(
      available: false,
      professionals: 0,
      services: 0,
      tutors: 0,
      pets: 0,
      monthlyAppointments: 0,
    );
  }
  final v = _map(value);
  return TenantMetrics(
    professionals: v['professionals'] as int,
    services: v['services'] as int,
    tutors: v['tutors'] as int,
    pets: v['pets'] as int,
    monthlyAppointments: v['monthlyAppointments'] as int,
  );
}

List<OnboardingStep> _onboarding(List values) {
  final steps = values.map((item) {
    final s = _map(item);
    return OnboardingStep(s['label'] as String, s['completed'] as bool);
  }).toList();
  if (steps.length != 4) return steps;
  return [
    OnboardingStep('Empresa criada', steps[0].completed),
    OnboardingStep('Gestor cadastrado', steps[1].completed),
    OnboardingStep('Horário de funcionamento configurado', steps[3].completed),
    OnboardingStep('Serviço cadastrado', steps[2].completed),
    const OnboardingStep('Profissional cadastrado', false, verified: false),
    const OnboardingStep(
      'Pronto para receber agendamentos',
      false,
      verified: false,
    ),
  ];
}

class FirebaseSaasRepository
    implements
        SaasRepository,
        SaasSession,
        SaasAdministration,
        SaasGoogleAccess,
        SaasSupportDesk,
        SaasBillingDesk,
        SaasRenewalDesk,
        LiveSignalsAware,
        NetworkProblemSource {
  FirebaseSaasRepository(
    this._gateway,
    this._cache, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final LocalFirebaseGateway _gateway;
  final DateTime Function() _clock;

  /// The offline copy opens only up to 24 hours after the latest
  /// confirmation with the server (access and e-mail code still valid).
  static const offlineLimit = Duration(hours: 24);
  static const offlineExpired =
      'A consulta offline vale por 24 horas depois da última conexão. '
      'Conecte-se à internet para entrar de novo.';

  /// Reason of the latest call without answer, for the read-only banner.
  @override
  NetworkProblem? get lastNetworkProblem => _gateway.lastNetworkProblem;
  @override
  LiveSignalSource? get liveSignals => _gateway.liveSignals;
  final SqlSnapshotCache _cache;
  final ExplicitCommands _commands = ExplicitCommands();
  @override
  bool requiresEmailCode = false;
  @override
  bool get authenticated => _gateway.uid != null;
  String? _emailChallenge;
  int _epoch = 0;
  Future<void> _ending = Future.value();
  Map<String, dynamic>? _profile;
  final Set<String> _offlineResources = {};
  final Set<String> _refreshed = {};
  final Map<String, DateTime> _times = {};
  @override
  bool get readOnly => _offlineResources.isNotEmpty;
  @override
  DateTime? get updatedAt =>
      _times.isEmpty ? null : (_times.values.toList()..sort()).first;
  @override
  String? cacheWarning;
  SuperAdmin _admin(Map<String, dynamic> value) => SuperAdmin(
    name: value['name'] as String,
    email: value['email'] as String,
  );
  void _check(int epoch, String? uid) {
    if (epoch != _epoch || uid == null || uid != _gateway.uid) {
      throw const SessionChangedException('Sessão encerrada.');
    }
  }

  Future<void> _context() async {
    final epoch = _epoch;
    final uid = _gateway.uid;
    final value = await _gateway.call('getSaasContext', {});
    _check(epoch, uid);
    if (value['uid'] != uid) {
      throw const SessionAccessException('Identidade divergente.');
    }
    final profile = _map(value['profile']);
    requiresEmailCode = value['requiresEmailCode'] == true;
    if (requiresEmailCode) {
      await _cache.clear();
      _check(epoch, uid);
      _profile = profile;
      return;
    }
    await _cache.bind(uid!, [
      {
        'id': 'platform',
        'profile': profile,
        'confirmedAt': _clock().toUtc().toIso8601String(),
      },
    ]);
    _check(epoch, uid);
    _profile = profile;
  }

  /// A copy without the confirmation time (earlier versions), past the limit
  /// or from a clock set back before it does not open offline.
  bool _offlineValid(Map<String, dynamic> scope) {
    final value = scope['confirmedAt'];
    final confirmed = value is String ? DateTime.tryParse(value) : null;
    if (confirmed == null) return false;
    final now = _clock();
    return !now.isBefore(confirmed.subtract(const Duration(minutes: 5))) &&
        now.isBefore(confirmed.add(offlineLimit));
  }

  /// Expired copy: erased together with the session, and the reason goes to
  /// the login.
  Future<Never> _expireOffline() async {
    await signOut();
    throw const SessionAccessException(offlineExpired);
  }

  @override
  Future<SuperAdmin> signIn(String email, String password) async {
    await _ending;
    await signOut();
    try {
      await _gateway.signIn(email, password);
      await _context();
      if (!requiresEmailCode) await _gateway.call('recordSaasSession', {});
      return _admin(_profile!);
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  /// Google proves the identity only. The same context check, e-mail code
  /// and session record of the password sign-in still apply.
  @override
  Future<SuperAdmin> signInWithGoogle() async {
    await _ending;
    await signOut();
    try {
      await _gateway.signInWithGoogle();
      await _context();
      if (!requiresEmailCode) await _gateway.call('recordSaasSession', {});
      return _admin(_profile!);
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<void> linkGoogle() => _gateway.linkGoogle();
  @override
  List<String> get providers => _gateway.providers;

  @override
  Future<List<SupportRequest>> supportRequests() async {
    final epoch = _epoch, uid = _gateway.uid;
    final value = await _gateway.call('getSaasSupportRequests', {});
    _check(epoch, uid);
    return (value['items'] as List).map((item) {
      final v = _map(item);
      return SupportRequest(
        id: v['id'] as String,
        tenantId: v['tenantId'] as String,
        tenantName: v['tenantName'] as String? ?? '',
        authorName: v['authorName'] as String? ?? '',
        subject: v['subject'] as String? ?? '',
        message: v['message'] as String? ?? '',
        status: v['status'] as String? ?? '',
        createdAt: _date(v['createdAt']),
        updatedAt: _date(v['updatedAt'] ?? v['createdAt']),
        replies: ((v['replies'] as List?) ?? const []).map((raw) {
          final r = _map(raw);
          return SupportMessage(
            fromPlatform: r['from'] == 'PLATFORM',
            authorName: r['authorName'] as String? ?? '',
            message: r['message'] as String? ?? '',
            at: _date(r['at']),
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  Future<BillingQueue> billingRequests() async {
    final epoch = _epoch, uid = _gateway.uid;
    final value = await _gateway.call('getBillingRequests', {});
    _check(epoch, uid);
    final counts = _map(value['counts'] ?? const {});
    int count(String key) => (counts[key] as num?)?.toInt() ?? 0;
    return BillingQueue(
      items: ((value['items'] as List?) ?? const []).map((item) {
        final v = _map(item);
        return BillingRequest(
          id: v['id'] as String,
          kind: v['kind'] as String? ?? '',
          ownerName: v['ownerName'] as String? ?? '',
          amountCents: (v['amountCents'] as num?)?.toInt() ?? 0,
          direction: v['direction'] as String? ?? 'CHARGE',
          tenantNames: ((v['tenantNames'] as List?) ?? const [])
              .cast<String>(),
          fromPlanName: v['fromPlanName'] as String?,
          toPlanName: v['toPlanName'] as String?,
          days: (v['days'] as num?)?.toInt(),
          reason: v['reason'] as String?,
          createdAt: v['createdAt'] == null ? null : _date(v['createdAt']),
        );
      }).toList(),
      planChanges: count('planChanges'),
      charges: count('charges'),
      refunds: count('refunds'),
      renewals: count('renewals'),
      supportWaiting: count('supportWaiting'),
      supportCapped: counts['supportCapped'] == true,
    );
  }

  /// "Renovar até" (E2): the cycle of the manager subscription goes up to
  /// the end of [day], in the zone of the account.
  @override
  Future<void> renewSubscriptionUntil(
    String tenantId,
    DateTime day,
    String reason,
  ) => _write('renewSubscriptionUntil', {
    'tenantId': tenantId,
    'until':
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
    'reason': reason,
  });

  @override
  Future<void> decideBillingRequest(
    String id, {
    required bool approve,
    String reason = '',
  }) => _write('decideBillingRequest', {
    'billingRequestId': id,
    'decision': approve ? 'APPROVE' : 'REJECT',
    'reason': reason,
  });

  @override
  Future<void> replySupportRequest(
    String id,
    String message, {
    required bool close,
  }) => _write('replySupportRequest', {
    'supportRequestId': id,
    'message': message,
    'close': close,
  });

  @override
  Future<SuperAdmin?> restore() async {
    final uid = _gateway.uid;
    if (uid == null || await _cache.owner != uid) {
      await _cache.clear();
      return null;
    }
    try {
      await _context();
    } on NetworkException {
      final scopes = await _cache.scopes(uid);
      if (scopes.length != 1 || scopes.single['id'] != 'platform') return null;
      if (!_offlineValid(scopes.single)) await _expireOffline();
      _profile = _map(scopes.single['profile']);
      _offlineResources.addAll(['tenants', 'plans', 'subscriptions', 'audit']);
    } on SessionAccessException {
      await signOut();
      return null;
    }
    return _profile == null ? null : _admin(_profile!);
  }

  Future<List<Map<String, dynamic>>> _read(String resource) async {
    final epoch = _epoch;
    final uid = _gateway.uid;
    try {
      await _context();
      final rows = <Map<String, dynamic>>[];
      String? cursor;
      do {
        final value = await _gateway.call('getSaasData', {
          'resource': resource,
          'cursor': cursor,
        });
        _check(epoch, uid);
        rows.addAll((value['items'] as List).map(_map));
        cursor = value['nextCursor'] as String?;
      } while (cursor != null);
      final now = DateTime.now();
      await _cache.write(uid!, 'platform', resource, rows, updatedAt: now);
      _check(epoch, uid);
      _offlineResources.remove(resource);
      _times[resource] = now;
      _refreshed.add(resource);
      if (_refreshed.length == 4 && _offlineResources.isEmpty) {
        cacheWarning = null;
        _commands.clear();
      }
      return rows;
    } on NetworkException {
      _check(epoch, uid);
      // The app may have stayed open offline beyond the limit.
      final scopes = await _cache.scopes(uid!);
      _check(epoch, uid);
      if (scopes.any((scope) => !_offlineValid(scope))) await _expireOffline();
      final saved = await _cache.read(uid, 'platform', resource);
      _check(epoch, uid);
      if (saved == null) rethrow;
      _offlineResources.add(resource);
      _times[resource] = saved.updatedAt;
      return saved.items;
    } on SessionAccessException {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<List<Plan>> getPlans() async => (await _read('plans'))
      .map(
        (v) => Plan(
          id: v['id'] as String,
          recordNumber: readRecordNumber(v['recordNumber']),
          name: v['name'] as String,
          description: v['description'] as String,
          monthlyPrice: (v['monthlyPriceCents'] as num) / 100,
          maxProfessionals: v['maxProfessionals'] as int,
          maxUsers: v['maxUsers'] as int,
          features: (v['features'] as List).cast<String>(),
          active: v['active'] as bool,
        ),
      )
      .toList();
  @override
  Future<List<Subscription>> getSubscriptions() async =>
      (await _read('subscriptions'))
          .map(
            (v) => Subscription(
              id: v['id'] as String,
              recordNumber: readRecordNumber(v['recordNumber']),
              tenantId: v['tenantId'] as String,
              planId: v['planId'] as String,
              status: SubscriptionStatus.values.firstWhere(
                (s) => s.name.toUpperCase() == v['status'],
              ),
              startedAt: v['startedAt'] == null ? null : _date(v['startedAt']),
              renewsAt: v['renewsAt'] == null ? null : _date(v['renewsAt']),
              accountId: v['accountId'] as String?,
            ),
          )
          .toList();
  @override
  Future<List<AuditEvent>> getAuditEvents() async =>
      (await _read('audit'))
          .map(
            (v) => AuditEvent(
              id: v['id'] as String,
              action: v['action'] as String,
              admin: v['admin'] as String,
              createdAt: _date(v['createdAt']),
              entity: v['entity'] as String,
              result: v['result'] as String,
              tenantId: v['tenantId'] as String?,
              reason: v['reason'] as String?,
              details: v['details'] == null ? const {} : _map(v['details']),
              fromTenant: v['source'] == 'TENANT',
            ),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  @override
  Future<List<Tenant>> getTenants() async => (await _read('tenants'))
      .map(
        (v) => Tenant(
          id: v['id'] as String,
          recordNumber: readRecordNumber(v['recordNumber']),
          name: v['name'] as String? ?? v['tradeName'] as String,
          tradeName: v['tradeName'] as String,
          slug: v['slug'] as String? ?? v['id'] as String,
          document: v['document'] as String? ?? '',
          phone: v['phone'] as String? ?? '',
          email: v['email'] as String? ?? '',
          city: v['city'] as String? ?? '',
          state: v['state'] as String? ?? '',
          status: TenantStatus.values.firstWhere(
            (s) =>
                s.name.toUpperCase() ==
                (v['status'] == 'TRIAL' ? 'ACTIVE' : v['status']),
          ),
          planId: v['planId'] as String,
          createdAt: _date(v['createdAt']),
          responsible: v['responsible'] as String? ?? '',
          users: (v['users'] as List).map((item) {
            final u = _map(item);
            return TenantUser(
              id: u['id'] as String,
              recordNumber: readRecordNumber(u['recordNumber']),
              name: u['name'] as String,
              email: u['email'] as String,
              role: TenantRole.fromApi(u['role'] as String),
              createdAt: _date(u['createdAt']),
              active: u['active'] as bool,
              activationPending: u['activationPending'] == true,
              principal: u['principal'] == true,
              deletionPending: u['deletionPending'] == true,
              lastAccess: u['lastAccess'] == null
                  ? null
                  : _date(u['lastAccess']),
            );
          }).toList(),
          metrics: _metrics(v['metrics']),
          onboarding: _onboarding(v['onboarding'] as List),
        ),
      )
      .toList();
  Future<void> _write(String command, Map<String, dynamic> data) async {
    if (readOnly) {
      throw const FormatException(
        'Conecte-se e atualize para administrar a plataforma.',
      );
    }
    final epoch = _epoch;
    final uid = _gateway.uid;
    try {
      await _commands.run(command, data, _gateway.call);
      _check(epoch, uid);
      cacheWarning =
          'Alteração confirmada no servidor. Atualize as consultas para visualizar o estado completo.';
      _refreshed.clear();
      for (final resource in ['tenants', 'plans', 'subscriptions', 'audit']) {
        _check(epoch, uid);
        try {
          await _cache.invalidate(uid!, 'platform', resource);
        } catch (_) {
          cacheWarning =
              'Alteração confirmada. A cópia SQL não pôde ser atualizada. Conecte-se e atualize antes da consulta offline.';
        }
      }
    } on SessionAccessException {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<void> saveTenant(Tenant tenant) => _write('saveTenant', {
    'tenantId': tenant.id,
    'tenant': {
      'name': tenant.name,
      'tradeName': tenant.tradeName,
      'slug': tenant.slug,
      'document': tenant.document,
      'phone': tenant.phone,
      'email': tenant.email,
      'city': tenant.city,
      'state': tenant.state,
      'responsible': tenant.responsible,
      'planId': tenant.planId,
    },
  });
  @override
  Future<void> setTenantStatus(
    String id,
    TenantStatus status, [
    String? reason,
  ]) => _write('setTenantStatus', {
    'tenantId': id,
    'status': status.name.toUpperCase(),
    'reason': reason ?? '',
  });
  @override
  Future<void> saveMember(
    String tenantId,
    String name,
    String email,
    String role,
  ) => _write('saveTenantMember', {
    'tenantId': tenantId,
    'name': name,
    'email': email,
    'role': role,
  });
  @override
  Future<void> saveInitialManager(String tenantId, TenantUser manager) =>
      saveMember(tenantId, manager.name, manager.email, 'MANAGER');
  @override
  Future<void> setUserActive(String tenantId, String userId, bool active) =>
      _write('setTenantUserActive', {
        'tenantId': tenantId,
        'userId': userId,
        'active': active,
      });
  @override
  Future<void> deleteManagerAccount(String tenantId, String userId) =>
      _write('deleteManagerAccount', {
        'tenantId': tenantId,
        'userId': userId,
        'confirmed': true,
      });
  @override
  Future<void> savePlan(Plan plan) => _write('savePlan', {
    'planId': plan.id,
    'plan': {
      'name': plan.name,
      'description': plan.description,
      'monthlyPriceCents': (plan.monthlyPrice * 100).round(),
      'maxProfessionals': plan.maxProfessionals,
      'maxUsers': plan.maxUsers,
      'features': plan.features,
      'active': plan.active,
    },
  });
  @override
  Future<void> updateSubscription(
    String id,
    String planId,
    SubscriptionStatus status,
  ) => _write('updateSubscription', {
    'subscriptionId': id,
    'planId': planId,
    'status': status.name.toUpperCase(),
  });
  @override
  Future<String> requestEmailCode() async {
    final epoch = _epoch, uid = _gateway.uid;
    final response = await _gateway.call('requestSaasEmailCode', {});
    _check(epoch, uid);
    _emailChallenge = response['challengeId'] as String;
    return _emailChallenge!;
  }

  @override
  Future<SuperAdmin> verifyEmailCode(String code) async {
    final epoch = _epoch, uid = _gateway.uid;
    if (_emailChallenge == null) {
      throw const FormatException('Solicite um código primeiro.');
    }
    final response = await _gateway.call('verifySaasEmailCode', {
      'challengeId': _emailChallenge,
      'code': code.trim(),
    });
    _check(epoch, uid);
    await _gateway.acceptAdministrativeToken(response['customToken'] as String);
    _check(epoch, uid);
    await _context();
    if (requiresEmailCode) {
      throw const FormatException(
        'Não foi possível confirmar o acesso. Solicite outro código.',
      );
    }
    await _gateway.call('recordSaasSession', {});
    _emailChallenge = null;
    return _admin(_profile!);
  }

  @override
  Future<void> changePassword(String currentPassword, String password) async {
    if (readOnly || requiresEmailCode) {
      throw const FormatException(
        'Confirme o acesso online antes de alterar a senha.',
      );
    }
    try {
      await _gateway.call('changeSaasPassword', {
        'currentPassword': currentPassword,
        'password': password,
      });
    } on NetworkException {
      // Auth and audit are separate systems; never retry a password silently.
      await signOut();
      rethrow;
    }
    await signOut();
  }

  @override
  Future<PlatformHealth> health() async {
    final value = await _gateway.call('getSaasHealth', {});
    return PlatformHealth(
      ready: value['ready'] as bool,
      environment: value['environment'] as String,
      version: value['version'] as String?,
      checkedAt: _date(value['checkedAt']),
      services: {
        for (final key in ['functions', 'firestore', 'auth'])
          key: ServiceHealth(
            available: _map(value[key])['available'] as bool,
            latencyMs: _map(value[key])['latencyMs'] as int?,
          ),
      },
    );
  }

  @override
  Future<SupportDiagnostic> diagnose(String tenantId, String reason) async {
    final value = await _gateway.call('getSaasDiagnostics', {
      'tenantId': tenantId,
      'reason': reason,
      'requestId': newRecordId(),
    });
    return SupportDiagnostic(
      tenantId: value['tenantId'] as String,
      tenantStatus: value['tenantStatus'] as String,
      subscriptionStatus: value['subscriptionStatus'] as String?,
      checkedAt: _date(value['checkedAt']),
      onboarding: (value['onboarding'] as List).map((step) {
        final s = _map(step);
        return OnboardingStep(s['label'] as String, s['completed'] as bool);
      }).toList(),
    );
  }

  @override
  Future<void> signOut() {
    ++_epoch;
    _profile = null;
    requiresEmailCode = false;
    _emailChallenge = null;
    _times.clear();
    _refreshed.clear();
    _offlineResources.clear();
    cacheWarning = null;
    _commands.clear();
    _ending = _ending.catchError((Object _) {}).then((_) async {
      try {
        await _cache.clear();
      } finally {
        await _gateway.signOut();
      }
    });
    return _ending;
  }
}
