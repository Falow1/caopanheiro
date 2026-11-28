import '../domain/repositories/own_team_profile_repository.dart';
import '../domain/repositories/login_code_repository.dart';
import '../domain/repositories/push_registration_repository.dart';
import 'push_device.dart';
import '../domain/repositories/company_view_repository.dart';
import '../domain/repositories/customer_unlink_repository.dart';
import '../domain/repositories/staff_link_repository.dart';
import '../domain/repositories/staff_invitation_repository.dart';
import '../domain/repositories/team_login_repository.dart';
import '../domain/repositories/workforce_repository.dart';
import '../domain/repositories/manager_activation_repository.dart';
import '../domain/repositories/pet_execution_repository.dart';
import '../domain/repositories/transport_management_repository.dart';
import '../domain/repositories/transport_booking_repository.dart';
import '../domain/repositories/team_extras_repository.dart';
import '../domain/repositories/paused_access_repository.dart';
import '../domain/repositories/pet_service_repository.dart';
import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetPolicy;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart';

import '../domain/models.dart';
import '../domain/models/team_company.dart';
import '../domain/repositories/persistent_catalog_repository.dart';
import '../domain/repositories/customer_link_repository.dart';
import '../domain/repositories/tutor_join_link_repository.dart';
import 'team_json.dart';
import '../domain/repositories/scheduling_repository.dart';
import '../domain/models/scheduling_policy.dart';

class FirebaseLocalRepository
    implements
        AuthenticatedCatalogRepository,
        CompanyViewRepository,
        ManagementCompanyDirectory,
        TeamLoginRepository,
        StaffInvitationRepository,
        StaffLinkRepository,
        AccountDeletionRepository,
        ManagerActivationRepository,
        WorkforceRepository,
        PetExecutionRepository,
        CustomerLinkRepository,
        CustomerUnlinkRepository,
        TutorJoinLinkRepository,
        SchedulingRepository,
        AppointmentNotesRepository,
        TransportManagementRepository,
        DriverPositionRepository,
        TripEstimateRepository,
        OwnTeamProfileRepository,
        LoginCodeRepository,
        PushRegistrationRepository,
        PetServiceRepository,
        TransportBookingRepository,
        TeamExtrasRepository,
        PausedAccessRepository,
        ScreenTipsRepository,
        LiveSignalsAware,
        NetworkProblemSource {
  @override
  LiveSignalSource? get liveSignals => gateway.liveSignals;
  FirebaseLocalRepository(
    this._auth,
    this._db,
    this._functions, {
    this.host = '10.0.2.2',
  });
  @override
  Future<CompanyViewPage> companyView({
    required String tenantId,
    required TenantRole role,
    required String resource,
    String? cursor,
  }) => _remote(() async {
    final session = _session;
    final uid = currentUid;
    if (uid == null) throw const FormatException('Entre novamente.');
    final result = await _call('getCompanyView', {
      'tenantId': tenantId,
      'role': role.name.toUpperCase(),
      'resource': resource,
      'cursor': ?cursor,
    });
    if (session != _session || uid != currentUid) {
      throw const FormatException('Sessão encerrada.');
    }
    if (result['tenantId'] != tenantId ||
        result['role'] != role.name.toUpperCase() ||
        result['resource'] != resource) {
      throw const FormatException('Consulta de outra empresa.');
    }
    return CompanyViewPage(
      (result['items'] as List).map(jsonMap).toList(),
      result['nextCursor'] as String?,
    );
  });

  @override
  Future<Customer> unlinkCustomerAccount(String customerId) =>
      _remote(() async {
        final result = await entityCommand('unlinkCustomerAccount', {
          'customerId': customerId,
          'confirmed': true,
        });
        return customerFromJson(jsonMap(result['customer']));
      });
  @override
  Future<void> deleteOwnAccount(String password) => _remote(() async {
    try {
      await _call('deleteOwnAccount', {
        'requestId': newRecordId(),
        'password': password,
        'confirmed': true,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.details is Map &&
          e.details['reason'] == 'ACCOUNT_DELETION_PENDING') {
        throw FormatException(e.message ?? 'A exclusão precisa ser concluída.');
      }
      rethrow;
    }
  });
  @override
  bool get hasPendingCommands => _pending != null || _entityPending != null;

  /// Emulator host of a local build; null when connected to staging.
  final String? host;

  /// Server of the calls when the build names one ([buildApiServer]); null
  /// sends them to the Cloud Functions of the project or to the emulator.
  final Uri? _server = buildApiServer;

  /// Where a local build checks the server: the local server of the calls,
  /// when the build names one, or the functions emulator.
  Future<NetworkProblem?> _probe(String emulator) {
    final server = _server;
    return server == null
        ? probeConnection(emulator)
        : probeConnection(server.host, port: server.port);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  LocalFirebaseGateway get gateway =>
      LocalFirebaseGateway.attach(_auth, _functions, host);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  bool get extrasAvailable => true;
  @override
  List<String> get signInProviders =>
      _auth.currentUser?.providerData.map((p) => p.providerId).toList() ??
      const [];
  @override
  Future<void> linkGoogle() => _remote(() => gateway.linkGoogle());

  /// Google proves the identity; the same invitation and link checks of the
  /// password sign-in decide whether this account may enter.
  @override
  Future<InternalUser> signInWithGoogle() => _remote(() async {
    final generation = ++_session;
    _tenantId = null;
    _companies = const [];
    _managementCompanies = const [];
    _pausedCompanies = const [];
    _managementUid = null;
    _pending = null;
    _entityPending = null;
    try {
      await gateway.signInWithGoogle();
      if (generation != _session) {
        throw const FormatException('Sessão encerrada.');
      }
      return await _finishSignIn(generation);
    } on ManagerActivationRequired {
      rethrow;
    } on StaffActivationRequired {
      rethrow;
    } on AccessPausedRequired {
      rethrow;
    } catch (_) {
      // An identity without an active link must not stay signed in.
      if (generation == _session) await _auth.signOut();
      rethrow;
    }
  });

  @override
  Future<Map<String, dynamic>> companyQuery(
    String name, [
    Map<String, dynamic> input = const {},
  ]) => _remote(() async {
    final generation = _session, tenant = _tenantId;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    final result = await _call(name, {'tenantId': tenant, ...input});
    if (generation != _session || tenant != _tenantId) {
      throw const FormatException('Sessão encerrada.');
    }
    return result;
  });

  @override
  Future<Map<String, dynamic>> companyCommand(
    String name,
    Map<String, dynamic> input,
  ) => _remote(() => entityCommand(name, input));
  List<TeamCompany> _companies = const [];
  List<ManagementCompany> _managementCompanies = const [];
  List<PausedCompany> _pausedCompanies = const [];
  @override
  List<PausedCompany> get pausedCompanies => _pausedCompanies;

  @override
  Future<Map<String, dynamic>> pausedQuery(
    String tenantId,
    String name, [
    Map<String, dynamic> input = const {},
  ]) => _remote(() async {
    final generation = _session;
    if (!_pausedCompanies.any((item) => item.id == tenantId)) {
      throw const FormatException('Petshop indisponível.');
    }
    final result = await _call(name, {...input, 'tenantId': tenantId});
    if (generation != _session) {
      throw const FormatException('Sessão encerrada.');
    }
    return result;
  });

  /// One attempt per call: the server refuses a second pending renewal, and a
  /// failed one can be sent again from the same screen.
  @override
  Future<Map<String, dynamic>> pausedCommand(
    String tenantId,
    String name,
    Map<String, dynamic> input,
  ) => pausedQuery(tenantId, name, {
    ...input,
    'requestId': List.generate(
      32,
      (_) => Random.secure().nextInt(16).toRadixString(16),
    ).join(),
  });
  String? _managementUid;
  @override
  List<ManagementCompany> get managementCompanies =>
      _managementUid == currentUid && currentUid != null
      ? _managementCompanies
      : const [];

  // Screen tips of the account, from the same team context and only for the
  // account that loaded it. Null when the server did not send them: then no
  // tip is offered.
  ScreenTips? _screenTips;
  @override
  ScreenTips? get screenTips =>
      _managementUid == currentUid && currentUid != null ? _screenTips : null;

  Future<void> _updateScreenTips(
    ScreenTips Function(ScreenTips) local,
    Map<String, dynamic> data,
  ) async {
    final tips = screenTips;
    if (tips == null) return;
    _screenTips = local(tips);
    await _remote(() => _call('updateScreenTips', data));
  }

  @override
  Future<void> markScreenTipsSeen(String screen) => _updateScreenTips(
    (tips) => tips.markSeen(screen),
    {'action': 'SEEN', 'screen': screen},
  );
  @override
  Future<void> turnOffScreenTips() =>
      _updateScreenTips((tips) => tips.turnOff(), {'action': 'OFF'});
  @override
  Future<void> resetScreenTips() =>
      _updateScreenTips((_) => const ScreenTips(), {'action': 'RESET'});

  String? _tenantId;
  int _session = 0;
  Map<String, dynamic>? _pending;
  String? _pendingFingerprint;
  Map<String, dynamic>? _entityPending;
  String? _entityFingerprint;

  /// [stagingOptions] are the options `flutterfire configure` generated for
  /// the app; read only by a staging build.
  static Future<FirebaseLocalRepository> connect({
    FirebaseOptions Function()? stagingOptions,
  }) async {
    if (buildFirebaseEnvironment == FirebaseEnvironment.staging) {
      final app = await initializeStagingApp(stagingOptions);
      final auth = FirebaseAuth.instanceFor(app: app);
      // E-mails of Auth (verification of the manager) in Portuguese.
      await auth.setLanguageCode('pt-BR');
      final db = FirebaseFirestore.instanceFor(app: app);
      db.settings = const Settings(persistenceEnabled: false);
      return FirebaseLocalRepository(
        auth,
        db,
        FirebaseFunctions.instanceFor(app: app, region: 'southamerica-east1'),
        host: null,
      );
    }
    const host = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '10.0.2.2',
    );
    if (host != '10.0.2.2' && host != '127.0.0.1' && host != 'localhost') {
      throw const FormatException(
        'Esta versão aceita somente emuladores locais.',
      );
    }
    final app = await Firebase.initializeApp(
      name: '[DEFAULT]',
      demoProjectId: 'demo-caopanheiro-local',
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);
    final functions = FirebaseFunctions.instanceFor(
      app: app,
      region: 'southamerica-east1',
    );
    await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
    db.settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
    functions.useFunctionsEmulator(host, 5001, automaticHostMapping: false);
    return FirebaseLocalRepository(auth, db, functions, host: host);
  }

  NetworkProblem? _lastNetworkProblem;

  /// Reason of the latest call without answer; kept for the read-only banner.
  @override
  NetworkProblem? get lastNetworkProblem => _lastNetworkProblem;

  /// The device confirms why no answer came; the reason is kept.
  Future<NetworkException> _noAnswer(NetworkProblem fallback) async {
    // A real project has no emulator to check: the assumed reason stays.
    final emulator = host;
    final failure = await confirmNetworkProblem(
      fallback,
      () async => emulator == null ? null : _probe(emulator),
    );
    _lastNetworkProblem = failure.problem;
    return failure;
  }

  /// [signingIn] marks the entries, where an unknown account means wrong
  /// credentials; elsewhere it means the session ended.
  Future<T> _remote<T>(
    Future<T> Function() operation, {
    bool signingIn = false,
  }) async {
    try {
      return await operation();
    } on NetworkException catch (error) {
      _lastNetworkProblem = error.problem;
      rethrow;
    } on TimeoutException {
      throw await _noAnswer(NetworkProblem.timeout);
    } on FirebaseAuthException catch (error) {
      final fallback = networkFallbackFor(error.code);
      if (fallback != null) throw await _noAnswer(fallback);
      throw authFailure(error.code, signingIn: signingIn);
    } on FirebaseFunctionsException catch (error) {
      if (isAppOutdated(error.code, error.details)) {
        throw const AppOutdatedException();
      }
      if (error.details is Map &&
          [
            'LOGIN_DENIED',
            'LOGIN_THROTTLED',
          ].contains(error.details['reason'])) {
        throw TeamLoginException(
          error.message ?? 'E-mail ou senha incorretos.',
          (error.details['retryAfterMs'] as num?)?.toInt() ?? 300,
        );
      }

      if (error.code == 'failed-precondition' &&
          error.details is Map &&
          error.details['reason'] == 'SERVICE_QUOTE_CHANGED') {
        throw ServiceQuoteChangedException(
          Map<String, dynamic>.from(error.details as Map),
        );
      }
      final fallback = networkFallbackFor(error.code);
      if (fallback != null) throw await _noAnswer(fallback);
      if (error.code == 'permission-denied' &&
          error.details is Map &&
          error.details['reason'] == 'BLOCK_SCOPE') {
        throw FormatException(
          error.message ?? 'Este bloqueio deve ser alterado pelo gestor.',
        );
      }
      if (['unauthenticated', 'permission-denied'].contains(error.code)) {
        throw SessionAccessException(error.message ?? 'Acesso indisponível.');
      }
      throw FormatException(error.message ?? 'Operação não autorizada.');
    } on FirebaseException catch (error) {
      if (['unavailable', 'deadline-exceeded'].contains(error.code)) {
        throw await _noAnswer(networkFallbackFor(error.code)!);
      }
      throw const SessionAccessException(
        'Não foi possível consultar os dados autorizados. Atualize ou entre novamente.',
      );
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    // Local-only transport probe avoids waiting for long Firebase retries when
    // the emulator host is disconnected, and tells no internet from server
    // down. It does not grant any access. A staging build has no host.
    final emulator = host;
    if (emulator != null) {
      final problem = await _probe(emulator);
      if (problem != null) throw NetworkException.of(problem);
    }
    final result = await callableOf(
      _functions,
      name,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      server: _server,
    ).call<Map<String, dynamic>>(withClientProtocol(data));
    return Map<String, dynamic>.from(result.data);
  }

  @override
  Future<List<Map<String, dynamic>>> workforceMembers() => _remote(() async {
    final epoch = _session, tenant = _tenantId;
    if (tenant == null) throw const FormatException('Selecione um petshop.');
    final result = await _call('getWorkforceMembers', {'tenantId': tenant});
    if (epoch != _session || tenant != _tenantId) {
      throw const FormatException('Sessão encerrada.');
    }
    return (result['members'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  });
  @override
  Future<void> saveWorkforceRoles(Map<String, dynamic> input) =>
      _remote(() async {
        await entityCommand('saveWorkforceRoles', input);
      });

  @override
  bool get invitationEmailVerified => _auth.currentUser?.emailVerified ?? false;
  @override
  Future<String> createStaffLink(Map<String, dynamic> input) =>
      _remote(() async {
        final response = await entityCommand('createStaffLink', input);
        return StaffLink(
          tenantId: response['tenantId'] as String,
          inviteId: response['inviteId'] as String,
          token: input['token'] as String,
        ).url;
      });
  @override
  Future<void> unlinkWorkforceMember(Map<String, dynamic> input) =>
      _remote(() async {
        await entityCommand('unlinkWorkforceMember', {
          ...input,
          'confirmed': true,
        });
      });
  @override
  Future<Map<String, dynamic>> inspectStaffLink(StaffLink link) =>
      _remote(() => _call('inspectStaffLink', link.data));
  @override
  Future<void> authenticateStaffLink(
    StaffLink link, {
    required String email,
    required String password,
    required bool createAccount,
  }) => _remote(() async {
    final generation = ++_session;
    _tenantId = null;
    _companies = const [];
    _managementCompanies = const [];
    _pausedCompanies = const [];
    _managementUid = null;
    _pending = null;
    _entityPending = null;
    await _auth.signOut();
    if (createAccount) {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (generation != _session) {
        await _auth.signOut();
        throw const FormatException('Sessão encerrada.');
      }
      await credential.user?.sendEmailVerification();
    } else {
      final response = await _call('loginStaffLink', {
        ...link.data,
        'email': email.trim(),
        'password': password,
      });
      if (generation != _session) {
        throw const FormatException('Sessão encerrada.');
      }
      await _auth.signInWithCustomToken(response['customToken'] as String);
    }
    if (generation != _session) {
      await _auth.signOut();
      throw const FormatException('Sessão encerrada.');
    }
  }, signingIn: true);
  @override
  Future<void> sendLinkVerification() => sendManagerVerification();
  @override
  Future<void> acceptStaffLink(
    StaffLink link, {
    required String name,
    required String phone,
    String? specialty,
  }) => _remote(() async {
    final generation = _session, user = _auth.currentUser;
    if (user == null) throw const FormatException('Entre novamente.');
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
    if (generation != _session || user.uid != _auth.currentUser?.uid) {
      throw const FormatException('Sessão encerrada.');
    }
    await _call('acceptStaffLink', {
      ...link.data,
      'name': name,
      'phone': phone,
      'specialty': ?specialty,
    });
    if (generation != _session) {
      throw const FormatException('Sessão encerrada.');
    }
  });

  @override
  Future<void> inviteWorkforceUser(Map<String, dynamic> input) =>
      _remote(() async {
        await entityCommand('inviteWorkforceUser', input);
      });
  @override
  Future<void> revokeWorkforceInvitation(String userId) => _remote(() async {
    await entityCommand('revokeWorkforceInvitation', {'userId': userId});
  });
  @override
  Future<void> sendStaffVerification() => sendManagerVerification();
  @override
  Future<void> completeStaffActivation({
    required String tenantId,
    required String name,
    required String phone,
  }) => _remote(() async {
    final generation = _session;
    final user = _auth.currentUser;
    if (user == null) throw const FormatException('Entre novamente.');
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
    if (generation != _session || user.uid != _auth.currentUser?.uid) {
      throw const FormatException('Sessão encerrada.');
    }
    await _call('completeStaffActivation', {
      'tenantId': tenantId,
      'name': name,
      'phone': phone,
    });
    if (generation != _session) {
      throw const FormatException('Sessão encerrada.');
    }
  });
  Future<StaffActivation> _loadStaffActivation(int generation) async {
    final result = await _call('getStaffActivation', {});
    if (generation != _session || result['uid'] != _auth.currentUser?.uid) {
      throw const FormatException('Sessão encerrada.');
    }
    return StaffActivation(
      email: result['email'] as String,
      emailVerified: result['emailVerified'] as bool,
      name: result['name'] as String,
      phone: result['phone'] as String,
      companies: (result['companies'] as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList(),
    );
  }

  @override
  Future<bool> hasManagerInvitation(String email) => _remote(
    () async =>
        (await _call('inspectTeamLogin', {
          'email': email.trim().toLowerCase(),
        }))['mode'] ==
        'INVITATION',
  );
  @override
  Future<void> resendManagerInvitation(String email) => _remote(() async {
    await _call('requestTeamLoginEmail', {
      'email': email.trim().toLowerCase(),
      'purpose': 'INVITATION',
    });
  });
  @override
  Future<void> requestManagerPassword(String email) => _remote(() async {
    await _call('requestTeamLoginEmail', {
      'email': email.trim().toLowerCase(),
      'purpose': 'PASSWORD_RESET',
    });
  });
  Future<void> _passwordLogin(
    String email,
    String password,
    int generation,
  ) async {
    final response = await _call('loginTeam', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    if (generation != _session) {
      throw const FormatException('Sessão encerrada.');
    }
    await _auth.signInWithCustomToken(response['customToken'] as String);
  }

  @override
  Future<ManagerActivation> beginManagerActivation(
    String email,
    String password,
  ) => _remote(() async {
    final generation = ++_session;
    _tenantId = null;
    _companies = const [];
    _managementCompanies = const [];
    _pausedCompanies = const [];
    _managementUid = null;
    _pending = null;
    _entityPending = null;
    await _auth.signOut();
    await _passwordLogin(email, password, generation);
    return _loadManagerActivation(generation);
  }, signingIn: true);

  Future<ManagerActivation> _loadManagerActivation(int generation) async {
    final result = await _call('getManagerActivation', {});
    if (generation != _session || result['uid'] != _auth.currentUser?.uid) {
      throw const FormatException('Sessão encerrada.');
    }
    return ManagerActivation(
      email: result['email'] as String,
      emailVerified: result['emailVerified'] as bool,
      name: result['name'] as String,
      phone: result['phone'] as String,
      companies: (result['companies'] as List).map((raw) {
        final c = Map<String, dynamic>.from(raw as Map);
        return ActivationCompany(
          id: c['id'] as String,
          name: c['name'] as String,
          phone: c['phone'] as String,
          city: c['city'] as String,
          state: c['state'] as String,
        );
      }).toList(),
    );
  }

  @override
  Future<void> sendManagerVerification() => _remote(() async {
    final user = _auth.currentUser;
    if (user == null) throw const FormatException('Entre novamente.');
    await user.sendEmailVerification();
  });

  @override
  Future<void> completeManagerActivation({
    required String tenantId,
    required String name,
    required String phone,
    required String companyPhone,
    required String city,
    required String state,
  }) => _remote(() async {
    final generation = _session;
    final user = _auth.currentUser;
    if (user == null) throw const FormatException('Entre novamente.');
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
    if (generation != _session || user.uid != _auth.currentUser?.uid) {
      throw const FormatException('Sessão encerrada.');
    }
    await _call('completeManagerActivation', {
      'tenantId': tenantId,
      'name': name,
      'phone': phone,
      'companyPhone': companyPhone,
      'city': city,
      'state': state,
    });
    if (generation != _session) {
      throw const FormatException('Sessão encerrada.');
    }
  });

  @override
  Future<InternalUser> signIn(String identifier, String password) =>
      _remote(() async {
        final generation = ++_session;
        _tenantId = null;
        _companies = const [];
        _managementCompanies = const [];
        _pausedCompanies = const [];
        _managementUid = null;
        _pending = null;
        _entityPending = null;
        await _auth.signOut();
        await _passwordLogin(identifier, password, generation);
        if (generation != _session) {
          await _auth.signOut();
          throw const FormatException('Sessão encerrada.');
        }
        return _finishSignIn(generation);
      }, signingIn: true);

  Future<InternalUser> _finishSignIn(int generation) async {
    final managerRequest = _loadManagerActivation(generation);
    final staffRequest = _loadStaffActivation(generation);
    // A manager invitation takes priority even if the staff request fails.
    staffRequest.ignore();
    final manager = await managerRequest;
    if (manager.companies.isNotEmpty) throw ManagerActivationRequired(manager);
    final staff = await staffRequest;
    if (staff.companies.isNotEmpty) throw StaffActivationRequired(staff);
    final companies = await getCompanies();
    if (generation != _session) {
      throw const FormatException('Sessão encerrada.');
    }
    if (companies.isEmpty && _pausedCompanies.isNotEmpty) {
      throw AccessPausedRequired(_pausedCompanies);
    }
    return companies.first.user;
  }

  @override
  Future<List<TeamCompany>> getCompanies() => _remote(() async {
    final generation = _session;
    final result = await _call('getTeamContext', {});
    if (generation != _session || result['uid'] != _auth.currentUser?.uid) {
      throw const FormatException('Sessão encerrada.');
    }
    _companies = (result['companies'] as List).map((raw) {
      final value = Map<String, dynamic>.from(raw as Map);
      return TeamCompany(
        id: value['id'] as String,
        recordNumber: readRecordNumber(value['recordNumber']),
        name: value['name'] as String,
        user: InternalUser(
          name: value['userName'] as String,
          phone: value['userPhone'] as String? ?? '',
          managementDelegated: value['managementDelegated'] == true,
          managementPermissions: (value['managementPermissions'] as List?)
              ?.cast<String>(),
          role: TenantRole.fromApi(value['role'] as String),
          roles: (value['roles'] as List? ?? [value['role']])
              .map((r) => TenantRole.fromApi(r as String))
              .toList(),
          canManageBlocks: ['MANAGER', 'ATTENDANT'].contains(value['role']),
          canRunService: value['role'] == 'MANAGER',
        ),
        entitlements: CompanyEntitlements.fromJson(value['entitlements']),
        billing: CompanyBilling.fromJson(value['billing']),
      );
    }).toList();
    _pausedCompanies = List.unmodifiable(
      (result['pausedCompanies'] as List? ?? []).map(
        (raw) => PausedCompany.fromJson(Map<String, dynamic>.from(raw as Map)),
      ),
    );
    _managementCompanies = List.unmodifiable(
      (result['managementCompanies'] as List? ?? []).map((raw) {
        final value = Map<String, dynamic>.from(raw as Map);
        return ManagementCompany(
          id: value['id'] as String,
          name: value['name'] as String,
          status: value['status'] as String? ?? 'UNKNOWN',
        );
      }),
    );
    _screenTips = ScreenTips.fromJson(result['screenTips']);
    _managementUid = result['uid'] as String;
    _contextAt = DateTime.now();
    return _companies;
  });

  /// When the team context was last read in this session.
  DateTime? _contextAt;

  /// The companies read in the last 30 seconds of this session, or a new
  /// read: choosing a company right after the login listed them does not
  /// repeat the heaviest call. The server still checks every access.
  Future<List<TeamCompany>> recentCompanies() async {
    final at = _contextAt;
    if (at != null &&
        _companies.isNotEmpty &&
        DateTime.now().difference(at) < const Duration(seconds: 30)) {
      return _companies;
    }
    return getCompanies();
  }

  @override
  Future<InternalUser> selectCompany(String id) => _remote(() async {
    final companies = await recentCompanies();
    final matches = companies.where((company) => company.id == id);
    if (matches.isEmpty) {
      throw const FormatException('Vínculo com a empresa indisponível.');
    }
    _tenantId = id;
    _pending = null;
    _entityPending = null;
    return matches.first.user;
  });

  @override
  Future<void> signOut() async {
    // While the session still calls the server.
    await _push.unregister();
    ++_session;
    _contextAt = null;
    _tenantId = null;
    _companies = const [];
    _managementCompanies = const [];
    _pausedCompanies = const [];
    _managementUid = null;
    _pending = null;
    _entityPending = null;
    await _auth.signOut();
  }

  PetService _service(Map<String, dynamic> value, String id) => PetService(
    id: id,
    recordNumber: readRecordNumber(value['recordNumber']),
    name: value['name'] as String,
    description: value['description'] as String? ?? '',
    price: (value['priceCents'] as num).toInt() / 100,
    duration: (value['durationMinutes'] as num).toInt(),
    active: value['active'] as bool,
  );

  @override
  Future<List<PetService>> getServices() => _remote(() async {
    final generation = _session;
    final tenant = _tenantId;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    final companies = await getCompanies();
    if (!companies.any((company) => company.id == tenant)) {
      throw const FormatException('Acesso à empresa removido.');
    }
    final result = <PetService>[];
    Query<Map<String, dynamic>> page = _db
        .collection('tenants/$tenant/services')
        .orderBy(FieldPath.documentId)
        .limit(100);
    while (true) {
      final snapshot = await page
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      if (generation != _session || tenant != _tenantId) {
        throw const FormatException('Sessão encerrada.');
      }
      result.addAll(snapshot.docs.map((doc) => _service(doc.data(), doc.id)));
      if (snapshot.docs.length < 100) break;
      page = _db
          .collection('tenants/$tenant/services')
          .orderBy(FieldPath.documentId)
          .startAfterDocument(snapshot.docs.last)
          .limit(100);
    }
    return result;
  });

  Map<String, dynamic> _fields(PetService value) => {
    'name': value.name,
    'description': value.description,
    'priceCents': (value.price * 100).round(),
    'durationMinutes': value.duration,
    'active': value.active,
  };

  @override
  Future<PetService> saveService(
    PetService service, {
    PetService? original,
  }) => _remote(() async {
    final tenant = _tenantId;
    final generation = _session;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    final values = _fields(service);
    final changes = original == null
        ? values
        : Map<String, dynamic>.fromEntries(
            values.entries.where(
              (entry) => _fields(original)[entry.key] != entry.value,
            ),
          );
    if (changes.isEmpty) return original!;
    final deactivate =
        original != null && changes.length == 1 && changes['active'] == false;
    final name = original == null
        ? 'createService'
        : deactivate
        ? 'deactivateService'
        : 'updateService';
    final data = <String, dynamic>{
      'tenantId': tenant,
      if (original == null) 'service': changes else 'serviceId': service.id,
      if (original != null && !deactivate) 'changes': changes,
    };
    final fingerprint = jsonEncode([name, data]);
    if (_pending != null && _pendingFingerprint != fingerprint) {
      throw const FormatException(
        'Há uma gravação sem confirmação. Mantenha os mesmos campos e tente salvar novamente antes de outra alteração.',
      );
    }
    _pending ??= {
      ...data,
      'requestId': List.generate(
        32,
        (_) => Random.secure().nextInt(16).toRadixString(16),
      ).join(),
    };
    _pendingFingerprint = fingerprint;
    try {
      final response = await _call(name, _pending!);
      if (generation != _session || tenant != _tenantId) {
        throw const FormatException('Sessão encerrada.');
      }
      _pending = null;
      final confirmed = Map<String, dynamic>.from(response['service'] as Map);
      return _service(confirmed, confirmed['id'] as String);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition' &&
          error.details is Map &&
          error.details['reason'] == 'SERVICE_QUOTE_CHANGED') {
        throw ServiceQuoteChangedException(
          Map<String, dynamic>.from(error.details as Map),
        );
      }
      if (![
        'unavailable',
        'deadline-exceeded',
        'internal',
        'unknown',
        'cancelled',
      ].contains(error.code)) {
        _pending = null;
      }
      rethrow;
    }
  });

  @override
  Future<List<Customer>> getCustomers() => _remote(() async {
    final generation = _session;
    final tenant = _tenantId;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    final result = <Customer>[];
    String? cursor;
    do {
      final page = await _call('getTeamCustomers', {
        'tenantId': tenant,
        'cursor': ?cursor,
      });
      if (generation != _session || tenant != _tenantId) {
        throw const FormatException('Sessão encerrada.');
      }
      result.addAll(
        (page['customers'] as List).map(
          (value) => customerFromJson(jsonMap(value)),
        ),
      );
      cursor = page['nextCursor'] as String?;
    } while (cursor != null);
    return result;
  });
  @override
  Future<List<Appointment>> getAppointments() => _remote(
    () async =>
        (await _resource('appointments')).map(appointmentFromJson).toList(),
  );
  @override
  Future<List<Professional>> getProfessionals() => _remote(
    () async =>
        (await _resource('professionals')).map(professionalFromJson).toList(),
  );
  @override
  Future<List<ScheduleBlock>> getBlocks() => _remote(
    () async => (await _resource('blocks')).map(blockFromJson).toList(),
  );
  @override
  Future<Customer> saveCustomer(Customer customer) => _remote(() async {
    final response = await entityCommand('saveCustomer', {
      'customerId': customer.id,
      'customer': {
        'name': customer.name,
        'phone': customer.phone,
        'email': customer.email,
      },
    });
    return customerFromJson(jsonMap(response['customer']));
  });
  @override
  Future<Customer> savePet(String customerId, Pet pet) => _remote(() async {
    final response = await entityCommand('savePet', {
      'customerId': customerId,
      'petId': pet.id,
      'pet': petCommandJson(pet),
    });
    return customerFromJson(jsonMap(response['customer']));
  });

  @override
  Future<PetPolicy> getPetPolicy() => _remote(() async {
    final generation = _session;
    final tenant = _tenantId;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    final result = await _call('getPetPolicy', {'tenantId': tenant});
    if (generation != _session || tenant != _tenantId) {
      throw const FormatException('Sessão encerrada.');
    }
    return PetPolicy.fromJson(result['policy']);
  });

  @override
  Future<PetPolicy> savePetPolicy(PetPolicy policy, {String? tenantId}) =>
      _remote(() async {
        // Another petshop of the same manager ("Aplicar também a"): its own
        // operation, checked by the server for that petshop.
        if (tenantId != null && tenantId != _tenantId) {
          final generation = _session;
          final result = await _call('savePetPolicy', {
            'tenantId': tenantId,
            'requestId': List.generate(
              32,
              (_) => Random.secure().nextInt(16).toRadixString(16),
            ).join(),
            'policy': policy.toJson(),
          });
          if (generation != _session) {
            throw const FormatException('Sessão encerrada.');
          }
          return PetPolicy.fromJson(result['policy']);
        }
        final response = await entityCommand('savePetPolicy', {
          'policy': policy.toJson(),
        });
        return PetPolicy.fromJson(response['policy']);
      });

  @override
  Future<int> blockPet(String customerId, String petId, String reason) =>
      _remote(() async {
        final response = await entityCommand('blockPet', {
          'customerId': customerId,
          'petId': petId,
          'reason': reason,
        });
        return (response['futureAppointments'] as num?)?.toInt() ?? 0;
      });

  @override
  Future<void> unblockPet(String customerId, String petId) => _remote(() async {
    await entityCommand('unblockPet', {
      'customerId': customerId,
      'petId': petId,
    });
  });

  Future<Map<String, dynamic>> entityCommand(
    String name,
    Map<String, dynamic> fields,
  ) async {
    final generation = _session;
    final tenant = _tenantId;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    final input = {'tenantId': tenant, ...fields};
    final fingerprint = jsonEncode([name, input]);
    if (_entityPending != null && _entityFingerprint != fingerprint) {
      throw const FormatException(
        'Há uma operação sem confirmação. Repita os mesmos dados antes de iniciar outra alteração.',
      );
    }
    _entityPending ??= {
      ...input,
      'requestId': List.generate(
        32,
        (_) => Random.secure().nextInt(16).toRadixString(16),
      ).join(),
    };
    _entityFingerprint = fingerprint;
    try {
      final response = await _call(name, _entityPending!);
      if (generation != _session || tenant != _tenantId) {
        throw const FormatException('Sessão encerrada.');
      }
      _entityPending = null;
      return response;
    } on FirebaseFunctionsException catch (error) {
      if (![
        'unavailable',
        'deadline-exceeded',
        'internal',
        'unknown',
        'cancelled',
      ].contains(error.code)) {
        _entityPending = null;
      }
      rethrow;
    }
  }

  @override
  Future<String> createTutorLink(String customerId) => _remote(() async {
    final generation = _session;
    final tenant = _tenantId;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    final result = await _call('createTutorLink', {
      'tenantId': tenant,
      'customerId': customerId,
    });
    if (generation != _session || tenant != _tenantId) {
      throw const FormatException('Sessão encerrada.');
    }
    return result['code'] as String;
  });

  @override
  Future<TutorJoinLink> getTutorJoinLink() => _remote(() async {
    final tenant = _tenantId;
    final result = await scopedQuery('getTutorJoinLink', const {});
    if (result['tenantId'] != tenant) {
      throw const FormatException('Consulta de outra empresa.');
    }
    return TutorJoinLink.fromJson(result);
  });

  @override
  Future<void> setTutorJoinLink(TutorJoinLinkAction action) =>
      _remote(() async {
        await entityCommand('setTutorJoinLink', {
          'action': action.name.toUpperCase(),
          'confirmed': true,
        });
      });

  @override
  Future<void> decideTutorReturn(String uid, {required bool approve}) =>
      _remote(() async {
        await entityCommand('decideTutorReturn', {
          'targetUid': uid,
          'decision': approve ? 'APPROVE' : 'REFUSE',
          'confirmed': true,
        });
      });

  Future<Map<String, dynamic>> scopedQuery(
    String name,
    Map<String, dynamic> input,
  ) async {
    final generation = _session;
    final tenant = _tenantId;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    final result = await _call(name, {'tenantId': tenant, ...input});
    if (generation != _session || tenant != _tenantId) {
      throw const FormatException('Sessão encerrada.');
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _resource(String resource) async {
    final result = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final page = await scopedQuery('getTeamResource', {
        'resource': resource,
        'cursor': ?cursor,
      });
      result.addAll((page['items'] as List).map(jsonMap));
      cursor = page['nextCursor'] as String?;
    } while (cursor != null);
    return result;
  }

  @override
  Future<Professional> saveProfessional(Professional professional) =>
      _remote(() async {
        final fields = professionalToJson(professional)
          ..remove('id')
          ..remove('recordNumber');
        final result = await entityCommand('saveProfessional', {
          'professionalId': professional.id,
          'professional': fields,
        });
        return professionalFromJson(jsonMap(result['professional']));
      });
  @override
  Future<ScheduleBlock> saveBlock(ScheduleBlock block) => _remote(() async {
    final fields = blockToJson(block)
      ..remove('id')
      ..remove('recordNumber')
      ..remove('canEdit')
      ..remove('editableUntil');
    final result = await entityCommand('saveBlock', {
      'blockId': block.id,
      'block': fields,
    });
    return blockFromJson(jsonMap(result['block']));
  });
  @override
  Future<void> removeBlock(String id) => _remote(() async {
    await entityCommand('removeBlock', {'blockId': id});
  });
  @override
  Future<Appointment> updateAppointmentNotes(String id, String notes) =>
      _remote(() async {
        final result = await entityCommand('updateAppointmentNotes', {
          'appointmentId': id,
          'notes': notes,
        });
        return appointmentFromJson(jsonMap(result['appointment']));
      });
  @override
  Future<Appointment> saveAppointment(Appointment value) => _remote(() async {
    final result = await entityCommand('saveAppointment', {
      'appointmentId': value.id,
      'customerId': value.customer.id,
      'expectedPriceCents': (value.price * 100).round(),
      'expectedDurationMinutes': value.duration,
      'expectedServices': value.items
          .map(
            (item) => {
              'petId': item.pet.id,
              'services': item.services
                  .map(
                    (service) => {
                      'id': service.id,
                      'priceCents': (service.price * 100).round(),
                      'durationMinutes': service.duration,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'startsAt': value.startsAt.toUtc().toIso8601String(),
      'items': _selection(value.items),
      if (value.professionalId != null) 'professionalId': value.professionalId,
      'notes': value.notes,
    });
    return appointmentFromJson(jsonMap(result['appointment']));
  });
  @override
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status,
  ) => _changeStatus(id, status, null);
  @override
  Future<Appointment> updatePetStatus(
    String id,
    String petId,
    AppointmentStatus status,
  ) => _changeStatus(id, status, petId);
  Future<Appointment> _changeStatus(
    String id,
    AppointmentStatus status,
    String? petId,
  ) => _remote(() async {
    final result = await entityCommand('updateAppointmentStatus', {
      'appointmentId': id,
      'status': status.apiValue,
      'petId': ?petId,
    });
    return appointmentFromJson(jsonMap(result['appointment']));
  });
  List<Map<String, dynamic>> _selection(List<AppointmentItem> items) => items
      .map(
        (item) => {
          'petId': item.pet.id,
          'serviceIds': item.services.map((service) => service.id).toList(),
        },
      )
      .toList();
  @override
  Future<List<AvailableSlot>> getAvailableSlots(
    String customerId,
    List<AppointmentItem> items,
    DateTime day, {
    String? appointmentId,
  }) => _remote(() async {
    final response = await scopedQuery('getAvailableSlots', {
      'customerId': customerId,
      'day': civilDate(day),
      'appointmentId': ?appointmentId,
      'items': _selection(items),
    });
    return (response['slots'] as List).map((raw) {
      final value = jsonMap(raw);
      return AvailableSlot(
        startsAt: DateTime.parse(value['startsAt'] as String),
        label: value['label'] as String,
        professionalId: value['professionalId'] as String,
        professionalName: value['professionalName'] as String,
      );
    }).toList();
  });
  @override
  Future<SchedulingPolicy> getSchedulingPolicy() => _remote(
    () async => policyFromJson(await scopedQuery('getSchedulingPolicy', {})),
  );
  @override
  Future<SchedulingPolicy> saveSchedulingPolicy(SchedulingPolicy value) =>
      _remote(() async {
        final data = policyToJson(value)..remove('configured');
        return policyFromJson(
          await entityCommand('saveSchedulingPolicy', data),
        );
      });
  @override
  Future<List<CompanyDriver>> getDrivers() => _remote(() async {
    final generation = _session;
    final tenant = _tenantId;
    final uid = currentUid;
    final drivers = <CompanyDriver>[];
    final seen = <String>{};
    String? cursor;
    do {
      final response = await scopedQuery('getCompanyDrivers', {
        'cursor': cursor,
      });
      if (generation != _session || tenant != _tenantId || uid != currentUid) {
        throw const SessionChangedException('Sessão ou empresa alterada.');
      }
      for (final item in response['drivers'] as List) {
        final v = jsonMap(item);
        drivers.add(CompanyDriver(v['id'] as String, v['name'] as String));
      }
      cursor = response['nextCursor'] as String?;
      if (cursor != null && !seen.add(cursor)) {
        throw const FormatException(
          'A lista de entregadores não avançou. Atualize e tente novamente.',
        );
      }
    } while (cursor != null);
    return drivers;
  });
  @override
  Future<void> createTransport(TransportRequest request) => _remote(() async {
    await entityCommand('createTransport', {
      'transportId': request.id,
      'appointmentId': request.appointmentId,
      'driverUid': request.driverUid,
      'type': request.type,
      'localScheduledAt': companyClockLabel(request.scheduledAt),
      'origin': request.origin,
      'destination': request.destination,
      'notes': request.notes,
      'estimatedDurationMinutes': request.estimatedDurationMinutes,
      'conflictAcknowledgement': request.conflictAcknowledgement,
    });
  });
  @override
  Future<List<ManagedTransport>> getTransports({
    String? appointmentId,
  }) => _remote(() async {
    final rows = <ManagedTransport>[];
    String? cursor;
    do {
      final response = await scopedQuery('getCompanyTransports', {
        'cursor': cursor,
        'appointmentId': appointmentId,
      });
      for (final raw in response['items'] as List) {
        final v = jsonMap(raw);
        final incidents = (v['incidents'] as List? ?? []);
        final pets = (v['pets'] as List? ?? []).map(jsonMap).toList();
        final checks = <String>[];
        for (final field in ['collectionChecks', 'deliveryChecks']) {
          if (v[field] != null) {
            for (final raw in jsonMap(v[field])['items'] as List) {
              final c = jsonMap(raw);
              final pet = pets.indexed
                  .where(
                    (entry) =>
                        (entry.$2['id'] ?? 'legacy-${entry.$1}') == c['petId'],
                  )
                  .firstOrNull
                  ?.$2;
              checks.add(
                '${field == 'collectionChecks' ? 'Coleta' : 'Entrega'} · ${pet?['name'] ?? c['petId']}: ${c['confirmed'] == true ? 'confirmada' : c['reason']}',
              );
            }
          }
        }
        rows.add(
          ManagedTransport(
            id: v['id'] as String,
            recordNumber: readRecordNumber(v['recordNumber']),
            appointmentNumber: readRecordNumber(v['appointmentNumber']),
            appointmentId: v['appointmentId'] as String,
            driverUid: v['driverUid'] as String,
            type: v['type'] as String,
            status: v['status'] as String,
            scheduledAt: DateTime.parse(v['scheduledAt'] as String).toLocal(),
            companyScheduledAt: v['localScheduledAt'] == null
                ? null
                : DateTime.parse(v['localScheduledAt'] as String),
            estimatedDurationMinutes: v['estimatedDurationMinutes'] as int?,
            checks: checks,
            incidents: incidents.indexed.map((entry) {
              final i = jsonMap(entry.$2);
              return ManagedIncident(
                i['id'] as String? ?? 'legacy-${entry.$1}',
                i['type'] as String,
                i['description'] as String,
                i['status'] as String? ?? 'OPEN',
                i['response'] as String? ?? '',
                i['resolution'] as String? ?? '',
              );
            }).toList(),
            history: ((v['assignmentHistory'] as List?) ?? []).map((raw) {
              final a = jsonMap(raw);
              return '${a['at']} · ${a['actorName']}: ${a['fromUid']} → ${a['toUid']}\n${a['reason']}${a['custodyConfirmed'] == true ? ' · Transferência física confirmada' : ''}';
            }).toList(),
          ),
        );
      }
      cursor = response['nextCursor'] as String?;
      if (rows.length > 1000) {
        throw const FormatException(
          'Há muitos transportes. Consulte por agendamento.',
        );
      }
    } while (cursor != null);
    rows.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return rows;
  });
  @override
  Future<TransportConflictPreview> conflicts(
    String driverUid,
    DateTime at,
    int? duration, {
    String? excludeId,
    String? appointmentId,
  }) => _remote(() async {
    final r = await scopedQuery('getTransportConflicts', {
      'driverUid': driverUid,
      if (appointmentId == null)
        'scheduledAt': at.toUtc().toIso8601String()
      else ...{
        'localScheduledAt': companyClockLabel(at),
        'appointmentId': appointmentId,
      },
      'estimatedDurationMinutes': duration,
      'excludeId': excludeId,
    });
    return TransportConflictPreview(
      (r['conflicts'] as List).map((raw) {
        final c = jsonMap(raw);
        final local = c['localScheduledAt'] as String?;
        final at = local == null
            ? DateTime.parse(c['scheduledAt'] as String).toLocal()
            : DateTime.parse(local);
        return '${c['id']} · ${at.toString().substring(0, 16)}';
      }).toList(),
      r['acknowledgement'] as String,
      r['incomplete'] as bool,
    );
  });
  @override
  Future<void> reassign(
    ManagedTransport t,
    String driverUid,
    String reason,
    bool custodyConfirmed,
    String acknowledgement,
  ) => _remote(() async {
    await entityCommand('reassignTransport', {
      'transportId': t.id,
      'driverUid': driverUid,
      'expectedDriverUid': t.driverUid,
      'expectedStatus': t.status,
      'reason': reason,
      'custodyConfirmed': custodyConfirmed,
      'conflictAcknowledgement': acknowledgement,
    });
  });
  @override
  Future<void> manageIncident(
    String transportId,
    String incidentId,
    String status,
    String message,
  ) => _remote(() async {
    await entityCommand('manageTransportIncident', {
      'transportId': transportId,
      'incidentId': incidentId,
      'status': status,
      'message': message,
    });
  });
  @override
  Future<DriverPosition> transportLocation(String transportId) => _remote(
    () async {
      return DriverPosition.fromJson(
        await scopedQuery('getTransportLocation', {'transportId': transportId}),
      );
    },
  );
  late final _push = PushDevice('equipe', (name, data) => _call(name, data));
  @override
  Future<void> registerPush() => _push.register();

  @override
  Future<String> requestLoginCode() => _remote(() async {
    final result = await _call('requestLoginCode', {});
    return result['challengeId'] as String;
  });
  @override
  Future<void> verifyLoginCode(String challengeId, String code) =>
      _remote(() async {
        await _call('verifyLoginCode', {
          'challengeId': challengeId,
          'code': code,
        });
      });
  @override
  Future<void> updateOwnProfile(String name, String phone) => _remote(() async {
    await _call('updateOwnTeamProfile', {'name': name, 'phone': phone});
  });
  @override
  Future<int> estimateTripMinutes(
    Map<String, String> origin,
    Map<String, String> destination,
  ) => _remote(() async {
    Map<String, String> place(Map<String, String> value) => {
      'street': value['street'] ?? '',
      'district': value['district'] ?? '',
    };
    final r = await scopedQuery('estimateTransportTrip', {
      'origin': place(origin),
      'destination': place(destination),
    });
    return (r['minutes'] as num).toInt();
  });
  @override
  Future<Map<String, dynamic>> bookingPolicy() async =>
      jsonMap((await scopedQuery('getTransportPolicy', {}))['policy']);
  @override
  Future<List<Map<String, dynamic>>> searchBookingAddress(String query) async =>
      ((await scopedQuery('searchTransportAddress', {'query': query}))['places']
              as List)
          .map(jsonMap)
          .toList();
  @override
  Future<void> saveBookingPolicy(Map<String, dynamic> policy) async {
    await entityCommand('saveTransportPolicy', {'policy': policy});
  }

  @override
  Future<List<Map<String, dynamic>>> bookingRequests() async {
    final result = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final page = await scopedQuery('getTransportRequests', {
        'cursor': cursor,
      });
      result.addAll((page['items'] as List).map(jsonMap));
      cursor = page['nextCursor'] as String?;
      if (result.length >= 1000 && cursor != null) {
        throw const FormatException(
          'Há muitos pedidos. Contate a administração.',
        );
      }
    } while (cursor != null);
    return result;
  }

  @override
  Future<void> decideBookingRequest(Map<String, dynamic> input) async {
    await entityCommand('decideTransportRequest', input);
  }
}
