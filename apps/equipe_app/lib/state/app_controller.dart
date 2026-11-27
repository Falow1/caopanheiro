import 'dart:async';

import '../domain/repositories/own_team_profile_repository.dart';
import '../domain/repositories/login_code_repository.dart';
import '../domain/repositories/push_registration_repository.dart';
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

import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTipsStore;

import '../domain/repositories/team_extras_repository.dart';
import '../domain/repositories/paused_access_repository.dart';
import '../domain/repositories/pet_service_repository.dart';
import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetPolicy;
import '../features/more/company_extras.dart';
import '../features/more/billing_models.dart';

import '../domain/repositories/internal_repository.dart';
import '../domain/repositories/persistent_catalog_repository.dart';
import '../domain/repositories/customer_link_repository.dart';
import '../domain/repositories/tutor_join_link_repository.dart';
import '../domain/repositories/scheduling_repository.dart';
import '../domain/models/scheduling_policy.dart';
import '../domain/models.dart';
import '../domain/models/team_company.dart';

class AppController extends AppControllerBase
    with LiveFollowing
    implements AppTipsStore {
  AppController(
    this._repository, {
    this.catalogOnly = false,
    this.unified = false,
    this.onSignOut,
    this.beforeSignIn,
  });
  bool get hasPendingCommands =>
      _repository is WorkforceRepository &&
      (_repository as WorkforceRepository).hasPendingCommands;
  final bool unified;
  final void Function()? onSignOut;
  final Future<void> Function()? beforeSignIn;
  Future<void> get closingSession => _closingSession ?? Future.value();
  TenantRole? _activeFunction;
  void setFunction(TenantRole role) {
    if (_user?.availableRoles.contains(role) != true) {
      throw const FormatException('Função indisponível.');
    }
    _activeFunction = role;
    notifyListeners();
  }

  int get sessionRevision => _sessionEpoch;

  /// Session and function in use, for actions that wait on a dialog: equal
  /// while neither changed. [user] builds a new object for the chosen
  /// function on every read, so it cannot be compared by identity.
  ({int revision, TenantRole? function}) get sessionKey =>
      (revision: _sessionEpoch, function: user?.role);
  final bool catalogOnly;
  int _sessionEpoch = 0;
  List<TeamCompany> _companies = const [];
  TeamCompany? _company;
  Future<void>? _closingSession;
  List<TeamCompany> get companies => _companies;
  TeamCompany? get company => _company;
  bool get isPrincipalAccount => [?company, ...companies].any(
    (value) =>
        !value.user.managementDelegated &&
        (value.user.isManager || value.user.roles.contains(TenantRole.manager)),
  );
  List<ManagementCompany> get profileCompanies {
    if (user?.isManager != true) return const [];
    final directory = _repository is ManagementCompanyDirectory
        ? (_repository as ManagementCompanyDirectory).managementCompanies
        : const <ManagementCompany>[];
    if (directory.isNotEmpty) return directory;
    return companies
        .where(
          (value) =>
              value.user.isManager ||
              value.user.roles.contains(TenantRole.manager),
        )
        .map((value) => ManagementCompany(id: value.id, name: value.name))
        .toList();
  }

  Future<CompanyViewPage> companyView({
    required String tenantId,
    required TenantRole role,
    required String resource,
    String? cursor,
  }) async {
    final epoch = _sessionEpoch;
    final source = _repository;
    if (source is! CompanyViewRepository) {
      throw const FormatException('Consulta de empresas indisponível.');
    }
    final result = await (source as CompanyViewRepository).companyView(
      tenantId: tenantId,
      role: role,
      resource: resource,
      cursor: cursor,
    );
    if (epoch != _sessionEpoch) {
      throw const FormatException('Contexto alterado.');
    }
    return result;
  }

  final InternalRepository _repository;
  PersistentCatalogRepository? get _persistent =>
      _repository is PersistentCatalogRepository ? _repository : null;
  bool get readOnly => catalogOffline || offline;

  @override
  Object? get networkProblemSource => _repository;
  bool get catalogOffline => _persistent?.offline ?? false;
  DateTime? get catalogUpdatedAt => _persistent?.catalogUpdatedAt;
  DateTime? get customersUpdatedAt => _persistent?.customersUpdatedAt;
  String? get localWarning => _persistent?.localWarning;
  bool _customersLoaded = false;
  bool _agendaLoaded = false;
  String? _agendaError;
  String? _customersError;
  bool get agendaLoaded => _agendaLoaded;
  String? get agendaError => _agendaError;
  String? get customersError => _customersError;
  DateTime? get agendaUpdatedAt => _persistent?.agendaUpdatedAt;
  SchedulingPolicy _policy = SchedulingPolicy.initial;
  SchedulingPolicy get schedulingPolicy => _policy;
  SchedulingRepository get _schedule => _repository as SchedulingRepository;
  bool get customersLoaded => _customersLoaded;

  void _clearCompanyData() {
    _services = const [];
    _customers = const [];
    _appointments = const [];
    _professionals = const [];
    _blocks = const [];
    _customersLoaded = false;
    _agendaLoaded = false;
    _agendaError = null;
    _customersError = null;
    _policy = SchedulingPolicy.initial;
    _petPolicy = const PetPolicy();
    _pendingTutorReturns = 0;
  }

  void _clearInvalidAccess() {
    if (_persistent?.accessInvalidated ?? false) signOut();
  }

  Future<bool> refreshCustomers() async {
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      try {
        final values = await _repository.getCustomers();
        if (epoch == _sessionEpoch) {
          _customers = values;
          _customersLoaded = true;
        }
        // The pet form lists only the breeds of the rule read here.
        try {
          await _loadPetPolicy(epoch);
        } catch (_) {}
      } catch (_) {
        if (epoch == _sessionEpoch) _clearInvalidAccess();
        rethrow;
      }
    });
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return false;
    }
    _customersError = success ? null : error;
    if (success) await refreshTutorLinkSummary();
    return success;
  }

  Future<bool> deleteOwnAccount(String password) async {
    if (isPrincipalAccount) {
      await runGuarded(() async {
        throw const FormatException(
          'A conta do gestor principal só pode ser excluída pela administração do Cãopanheiro.',
        );
      });
      return false;
    }
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      if (_repository is! AccountDeletionRepository) {
        throw const FormatException('Atualize a integração da conta.');
      }
      await (_repository as AccountDeletionRepository).deleteOwnAccount(
        password,
      );
    });
    if (!success || epoch != _sessionEpoch) return false;
    signOut();
    await closingSession;
    return true;
  }

  Future<bool> unlinkCustomerAccount(String customerId) => _sessionMutation((
    epoch,
  ) async {
    if (_repository is! CustomerUnlinkRepository) {
      throw const FormatException('Atualize a integração de clientes.');
    }
    final value = await (_repository as CustomerUnlinkRepository)
        .unlinkCustomerAccount(customerId);
    if (epoch != _sessionEpoch) return;
    _customers = [..._customers.where((item) => item.id != value.id), value];
  });

  Future<String?> createTutorLink(String customerId) async {
    final epoch = _sessionEpoch;
    String? result;
    await runGuarded(() async {
      if (_repository is! CustomerLinkRepository) {
        throw const FormatException(
          'Vínculo disponível apenas no modo integrado.',
        );
      }
      result = await (_repository as CustomerLinkRepository).createTutorLink(
        customerId,
      );
    });
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return null;
    }
    return result;
  }

  /// The selected petshop's fixed invite link: management with the Customers
  /// area, integrated and online, as the individual invite.
  bool get tutorJoinLinkAvailable {
    final current = user;
    return catalogOnly &&
        !catalogOffline &&
        company != null &&
        current != null &&
        current.isManager &&
        current.canManage('CUSTOMERS') &&
        _repository is TutorJoinLinkRepository;
  }

  /// Return requests of the fixed link waiting for the principal manager of
  /// the selected petshop; zero for anyone else.
  int get pendingTutorReturns => _pendingTutorReturns;
  int _pendingTutorReturns = 0;

  void _setPendingTutorReturns(int value) {
    if (value == _pendingTutorReturns) return;
    _pendingTutorReturns = value;
    notifyListeners();
  }

  /// Reads the count with the company view, which never creates the link:
  /// the link is born only when its area opens. The count is a hint, so a
  /// failure keeps the last one and shows nothing.
  Future<void> refreshTutorLinkSummary() async {
    final epoch = _sessionEpoch, tenant = company?.id;
    if (!tutorJoinLinkAvailable || tenant == null || !user!.isPrincipal) {
      _setPendingTutorReturns(0);
      return;
    }
    try {
      final page = await companyView(
        tenantId: tenant,
        role: TenantRole.manager,
        resource: 'tutorLink',
      );
      if (epoch != _sessionEpoch || tenant != company?.id) return;
      final row = page.items.isEmpty ? null : page.items.first;
      _setPendingTutorReturns((row?['pendingReturns'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  /// Opens the link area: the first reading creates the link. [quiet] is the
  /// live update, without loading state or error on the screen.
  Future<TutorJoinLink?> loadTutorJoinLink({bool quiet = false}) async {
    final epoch = _sessionEpoch, tenant = company?.id;
    TutorJoinLink? result;
    Future<void> read() async {
      if (_repository is! TutorJoinLinkRepository) {
        throw const FormatException(
          'Link de convite disponível apenas no modo integrado.',
        );
      }
      result = await (_repository as TutorJoinLinkRepository)
          .getTutorJoinLink();
    }

    final success = quiet ? await runQuietly(read) : await runGuarded(read);
    if (epoch != _sessionEpoch || tenant != company?.id) {
      if (!quiet) clearOperationState();
      return null;
    }
    final value = result;
    if (!success || value == null || value.tenantId != tenant) return null;
    if (value.canManage) _setPendingTutorReturns(value.requests.length);
    return value;
  }

  /// Principal only; the screen reads the link again afterwards.
  Future<bool> setTutorJoinLink(TutorJoinLinkAction action) =>
      _sessionMutation((epoch) async {
        if (_repository is! TutorJoinLinkRepository) {
          throw const FormatException('Atualize a integração de clientes.');
        }
        await (_repository as TutorJoinLinkRepository).setTutorJoinLink(action);
      });

  Future<bool> decideTutorReturn(String uid, {required bool approve}) =>
      _sessionMutation((epoch) async {
        if (_repository is! TutorJoinLinkRepository) {
          throw const FormatException('Atualize a integração de clientes.');
        }
        await (_repository as TutorJoinLinkRepository).decideTutorReturn(
          uid,
          approve: approve,
        );
      });

  Future<bool> restoreSession() async {
    final repository = _persistent;
    if (!catalogOnly || repository == null) return false;
    final epoch = _sessionEpoch;
    var restored = false;
    final success = await runGuarded(() async {
      if (!await repository.restoreSession() || epoch != _sessionEpoch) return;
      _companies = repository.authorizedCompanies;
      if (_companies.length == 1) {
        final company = _companies.first;
        final user = await repository.selectCompany(company.id);
        final services = user.hasTeamOperations
            ? await repository.getServices()
            : <PetService>[];
        if (epoch != _sessionEpoch) return;
        _company = company;
        _user = user;
        _services = services;
      }
      restored = true;
    });
    if (!success && repository.accessInvalidated) {
      _companies = const [];
      _company = null;
      _user = null;
      _services = const [];
    }
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return false;
    }
    if (success && restored) _registerPush();
    return success && restored;
  }

  /// This device in the push notifications, after each entry. A refusal or a
  /// failure never changes the entry.
  void _registerPush() {
    final Object repository = _repository;
    if (repository is PushRegistrationRepository) {
      unawaited(repository.registerPush().catchError((Object _) {}));
    }
  }

  /// Petshops with the access paused (E2), when the account has no other:
  /// the principal manager only opens the plan, Support and the export.
  List<PausedCompany> _pausedAccess = const [];
  List<PausedCompany> get pausedAccess => _pausedAccess;
  PausedCompany? _pausedCompany;
  PausedCompany? get pausedCompany => _pausedCompany;

  /// Opens a paused petshop for the plan, Support and the export only.
  void openPausedCompany(PausedCompany company) {
    if (!_pausedAccess.any((item) => item.id == company.id)) return;
    _pausedCompany = company;
    notifyListeners();
  }

  /// Notices of the expired plan already shown in the middle of the screen
  /// in this session (E2); afterwards only the corner notice stays.
  final Set<String> _billingNoticesSeen = {};
  bool billingNoticeSeen(String key) => _billingNoticesSeen.contains(key);
  void markBillingNoticeSeen(String key) {
    if (_billingNoticesSeen.add(key)) notifyListeners();
  }

  StaffActivation? _staffActivation;
  StaffActivation? get staffActivation => _staffActivation;
  ManagerActivation? _managerActivation;
  ManagerActivation? get managerActivation => _managerActivation;
  InternalUser? _user;
  List<Customer> _customers = const [];
  List<PetService> _services = const [];
  List<Appointment> _appointments = const [];
  List<Professional> _professionals = const [];
  List<ScheduleBlock> _blocks = const [];

  InternalUser? get user => _user == null
      ? null
      : _activeFunction == null ||
            !_user!.availableRoles.contains(_activeFunction)
      ? _user
      : _user!.asFunction(_activeFunction!);
  List<Customer> get customers => _customers;
  List<PetService> get services => _services;
  List<Appointment> get appointments => _appointments;
  List<Professional> get professionals => _professionals;
  List<ScheduleBlock> get blocks => _blocks;

  ManagerActivationRepository get _activation {
    if (_repository is! ManagerActivationRepository) {
      throw const FormatException('Primeiro acesso indisponível.');
    }
    return _repository as ManagerActivationRepository;
  }

  DateTime? loginRetryUntil;
  Future<bool> hasManagerInvitation(String email) async =>
      _repository is TeamLoginRepository
      ? await (_repository as TeamLoginRepository).hasManagerInvitation(email)
      : false;
  Future<bool> resendManagerInvitation(String email) => runGuarded(() async {
    if (_repository is! TeamLoginRepository) {
      throw const FormatException('Não foi possível solicitar o convite.');
    }
    await (_repository as TeamLoginRepository).resendManagerInvitation(email);
  });
  Future<bool> requestManagerPassword(String email) =>
      runGuarded(() => _activation.requestManagerPassword(email));
  Future<ManagerActivation?> beginManagerActivation(
    String email,
    String password,
  ) async {
    if (busy) return null;
    signOut();
    final epoch = _sessionEpoch;
    ManagerActivation? result;
    final success = await runGuarded(() async {
      await _closingSession;
      await beforeSignIn?.call();
      result = await _activation.beginManagerActivation(email, password);
    });
    return success && epoch == _sessionEpoch ? result : null;
  }

  Future<bool> sendManagerVerification() =>
      runGuarded(() => _activation.sendManagerVerification());
  Future<bool> completeManagerActivation({
    required String tenantId,
    required String name,
    required String phone,
    required String companyPhone,
    required String city,
    required String state,
  }) async {
    final epoch = _sessionEpoch;
    final success = await runGuarded(
      () => _activation.completeManagerActivation(
        tenantId: tenantId,
        name: name,
        phone: phone,
        companyPhone: companyPhone,
        city: city,
        state: state,
      ),
    );
    if (epoch != _sessionEpoch) return false;
    if (success) signOut();
    return success;
  }

  Future<List<Map<String, dynamic>>?> workforceMembers() async {
    final epoch = _sessionEpoch;
    List<Map<String, dynamic>>? result;
    await runGuarded(() async {
      try {
        result = await (_repository as WorkforceRepository).workforceMembers();
      } catch (_) {
        if (epoch == _sessionEpoch && _persistent?.accessInvalidated == true) {
          signOut();
        }
        rethrow;
      }
    });
    return epoch == _sessionEpoch ? result : null;
  }

  Future<bool> saveWorkforceRoles(Map<String, dynamic> input) async {
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      try {
        await (_repository as WorkforceRepository).saveWorkforceRoles(input);
      } catch (_) {
        if (epoch == _sessionEpoch && _persistent?.accessInvalidated == true) {
          signOut();
        }
        rethrow;
      }
    });
    if (success && epoch == _sessionEpoch) {
      _professionals = const [];
      await refreshProfessionals();
    }
    return success && epoch == _sessionEpoch;
  }

  StaffLinkRepository get _links {
    if (_repository is! StaffLinkRepository) {
      throw const FormatException('Convites por link indisponíveis.');
    }
    return _repository as StaffLinkRepository;
  }

  bool get invitationEmailVerified =>
      _repository is StaffLinkRepository && _links.invitationEmailVerified;
  Future<String?> createStaffLink(Map<String, dynamic> input) async {
    final epoch = _sessionEpoch;
    String? value;
    final success = await runGuarded(() async {
      value = await _links.createStaffLink(input);
    });
    return success && epoch == _sessionEpoch ? value : null;
  }

  Future<bool> unlinkWorkforceMember(Map<String, dynamic> input) async {
    final epoch = _sessionEpoch;
    final success = await _staffMutation(
      () => _links.unlinkWorkforceMember(input),
    );
    if (success && epoch == _sessionEpoch) await refreshProfessionals();
    // The mutation is confirmed even if the following catalog read fails.
    return success && epoch == _sessionEpoch;
  }

  Future<bool> refreshProfessionals() async {
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      try {
        final values = await _repository.getProfessionals();
        if (epoch == _sessionEpoch) _professionals = values;
      } catch (_) {
        if (epoch == _sessionEpoch) _clearInvalidAccess();
        rethrow;
      }
    });
    return success && epoch == _sessionEpoch;
  }

  Future<Map<String, dynamic>?> inspectStaffLink(StaffLink link) async {
    final epoch = _sessionEpoch;
    Map<String, dynamic>? value;
    final success = await runGuarded(() async {
      value = await _links.inspectStaffLink(link);
    });
    return success && epoch == _sessionEpoch ? value : null;
  }

  Future<bool> authenticateStaffLink(
    StaffLink link, {
    required String email,
    required String password,
    required bool createAccount,
  }) async {
    if (busy) return false;
    signOut();
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      await _closingSession;
      await beforeSignIn?.call();
      await _links.authenticateStaffLink(
        link,
        email: email,
        password: password,
        createAccount: createAccount,
      );
    });
    return success && epoch == _sessionEpoch;
  }

  Future<bool> sendLinkVerification() =>
      _staffMutation(() => _links.sendLinkVerification());
  Future<bool> acceptStaffLink(
    StaffLink link, {
    required String name,
    required String phone,
    String? specialty,
  }) async {
    final success = await _staffMutation(
      () => _links.acceptStaffLink(
        link,
        name: name,
        phone: phone,
        specialty: specialty,
      ),
    );
    if (success) signOut();
    return success;
  }

  StaffInvitationRepository get _staff {
    if (_repository is! StaffInvitationRepository) {
      throw const FormatException('Convites indisponíveis.');
    }
    return _repository as StaffInvitationRepository;
  }

  Future<bool> _staffMutation(Future<void> Function() operation) async {
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      try {
        await operation();
      } catch (_) {
        if (epoch == _sessionEpoch && _persistent?.accessInvalidated == true) {
          signOut();
        }
        rethrow;
      }
    });
    return success && epoch == _sessionEpoch;
  }

  Future<bool> inviteWorkforceUser(Map<String, dynamic> input) =>
      _staffMutation(() => _staff.inviteWorkforceUser(input));
  Future<bool> revokeWorkforceInvitation(String userId) =>
      _staffMutation(() => _staff.revokeWorkforceInvitation(userId));
  Future<bool> sendStaffVerification() =>
      _staffMutation(() => _staff.sendStaffVerification());
  Future<bool> completeStaffActivation({
    required String tenantId,
    required String name,
    required String phone,
  }) async {
    final success = await _staffMutation(
      () => _staff.completeStaffActivation(
        tenantId: tenantId,
        name: name,
        phone: phone,
      ),
    );
    if (success) signOut();
    return success;
  }

  TeamExtrasRepository? get _extras {
    final Object repository = _repository;
    return repository is TeamExtrasRepository && repository.extrasAvailable
        ? repository
        : null;
  }

  ScreenTipsRepository? get _tips {
    final Object repository = _repository;
    return repository is ScreenTipsRepository ? repository : null;
  }

  /// The account marks of the screen tips arrived from the server; without
  /// them (tests, cache only) no tip is shown and "Rever dicas" is hidden.
  bool get tipsAvailable => _tips?.screenTips != null;
  @override
  bool tipsPending(String screen) =>
      _tips?.screenTips?.pending(screen) ?? false;
  @override
  void markTipsSeen(String screen) =>
      _tipsWrite(_tips?.markScreenTipsSeen(screen));
  @override
  void turnOffTips() => _tipsWrite(_tips?.turnOffScreenTips());

  /// "Rever dicas": every screen shows its tips again on the next visit.
  void resetTips() => _tipsWrite(_tips?.resetScreenTips());

  // The mark changes at once; a failed write never holds the person and only
  // brings the tips back on the next access.
  void _tipsWrite(Future<void>? write) {
    notifyListeners();
    write?.then((_) {}, onError: (_) {});
  }

  /// Google replaces only the password; links and roles stay with the server.
  bool get googleAvailable => _extras != null;
  List<String> get signInProviders => _extras?.signInProviders ?? const [];
  Future<bool> signInWithGoogle() {
    final extras = _extras;
    if (extras == null) return Future.value(false);
    return _signInWith(extras.signInWithGoogle);
  }

  /// Second step of a new login (a code by e-mail), skippable in this
  /// demonstration because the server does not require it.
  String? _loginChallenge;
  bool get loginCodeAvailable => _repository is LoginCodeRepository;
  Future<bool> requestLoginCode() => runGuarded(() async {
    _loginChallenge = await (_repository as LoginCodeRepository)
        .requestLoginCode();
  });
  Future<bool> verifyLoginCode(String code) => runGuarded(() async {
    final challenge = _loginChallenge;
    if (challenge == null) {
      throw const FormatException(
        'Toque em Enviar código para receber um código.',
      );
    }
    await (_repository as LoginCodeRepository).verifyLoginCode(challenge, code);
    _loginChallenge = null;
  });

  /// The person edits their own name and phone; the e-mail stays the login.
  bool get ownProfileEditable =>
      _repository is OwnTeamProfileRepository && _user != null && !readOnly;
  Future<bool> updateOwnProfile(String name, String phone) => runGuarded(
    () async {
      if (_repository is! OwnTeamProfileRepository) {
        throw const FormatException('Edição do perfil indisponível.');
      }
      final epoch = _sessionEpoch;
      await (_repository as OwnTeamProfileRepository).updateOwnProfile(
        name,
        phone,
      );
      if (epoch != _sessionEpoch || _user == null) return;
      _user = _user!.withContact(name, phone);
      _companies = [
        for (final company in _companies)
          company.withUser(company.user.withContact(name, phone)),
      ];
      if (_company != null) {
        _company = _company!.withUser(_company!.user.withContact(name, phone));
      }
    },
  );

  Future<bool> linkGoogle() => runGuarded(() async {
    final extras = _extras;
    if (extras == null) {
      throw const FormatException('Vínculo com Google indisponível.');
    }
    await extras.linkGoogle();
  });

  /// Plan, support and notices need the server and one selected petshop.
  bool get companyExtrasAvailable =>
      _extras != null && _company != null && !readOnly;
  late final RoleNoticesSource _teamNoticesSource = _TeamNotices(this);

  /// In-app notices of management/attendance for the selected petshop.
  RoleNoticesSource? get teamNotices {
    final current = _user;
    if (!companyExtrasAvailable || current == null) return null;
    final roles = current.roles.isEmpty ? [current.role] : current.roles;
    return roles.any(
          (role) => role == TenantRole.manager || role == TenantRole.attendant,
        )
        ? _teamNoticesSource
        : null;
  }

  Future<Map<String, dynamic>> _companyQuery(
    String name, [
    Map<String, dynamic> input = const {},
  ]) async {
    final paused = _pausedTarget;
    if (paused != null) {
      final epoch = _sessionEpoch;
      final result = await paused.$1.pausedQuery(paused.$2, name, input);
      if (epoch != _sessionEpoch) {
        throw const FormatException('Sessão ou empresa alterada.');
      }
      return result;
    }
    final extras = _extras;
    if (extras == null) {
      throw const FormatException(
        'Recurso disponível apenas com conexão ao servidor.',
      );
    }
    final epoch = _sessionEpoch;
    final result = await extras.companyQuery(name, input);
    if (epoch != _sessionEpoch) {
      throw const FormatException('Sessão ou empresa alterada.');
    }
    return result;
  }

  /// Plan and subscription of the selected petshop, for consultation only.
  Future<CompanyPlanInfo> loadCompanyPlan() async =>
      CompanyPlanInfo.fromJson(await _companyQuery('getCompanyPlan'));

  /// Subscription of the principal manager, covering all their petshops
  /// (A1). Null for anyone without their own subscription: the screen then
  /// shows the plan of the selected petshop.
  Future<BillingOverview?> loadBillingOverview() async =>
      BillingOverview.fromJson(await _companyQuery('getBillingOverview'));

  /// Features of the plan of the selected petshop. The server decides each
  /// command; this only hides what the plan does not include.
  CompanyEntitlements get entitlements =>
      company?.entitlements ?? const CompanyEntitlements();

  /// Reads the features again after a plan change, keeping the selection.
  /// A failure keeps the last ones: the server still refuses what is closed.
  Future<void> refreshCompanyEntitlements() async {
    final epoch = _sessionEpoch, current = _company;
    if (!catalogOnly || current == null) return;
    try {
      final companies = await _repository.getCompanies();
      if (epoch != _sessionEpoch || _company?.id != current.id) return;
      final match = companies.where((item) => item.id == current.id);
      _companies = companies;
      if (match.isNotEmpty) _company = match.first;
      notifyListeners();
    } catch (_) {}
  }

  /// The paused petshop opened in this session (E2), without operation.
  (PausedAccessRepository, String)? get _pausedTarget {
    final Object repository = _repository;
    final paused = _pausedCompany;
    return _company == null &&
            paused != null &&
            repository is PausedAccessRepository
        ? (repository, paused.id)
        : null;
  }

  Future<void> _pausedCommand(String name, Map<String, dynamic> input) async {
    final target = _pausedTarget!;
    await target.$1.pausedCommand(target.$2, name, input);
  }

  /// "Já paguei" after paying the renewal outside the app (E2, path A):
  /// the platform checks the money and confirms 30 more days.
  Future<bool> requestRenewal() => _billingCommand('requestRenewal', {});

  /// Copy of the customers, pets and appointments of a petshop of the
  /// principal manager, as CSV files (E2). Nothing changes on the platform.
  Future<TenantExport> exportTenantData(String tenantId) async =>
      TenantExport.fromJson(
        await _companyQuery('exportTenantData', {'tenantId': tenantId}),
      );

  Future<bool> _billingCommand(String name, Map<String, dynamic> input) =>
      runGuarded(() async {
        if (_pausedTarget != null) return _pausedCommand(name, input);
        final extras = _extras;
        if (extras == null) {
          throw const FormatException(
            'Assinatura disponível apenas com conexão ao servidor.',
          );
        }
        await extras.companyCommand(name, input);
      });

  /// The platform confirms the payment and applies the change (A1-r).
  Future<bool> requestPlanChange(String planId) =>
      _billingCommand('requestPlanChange', {'planId': planId});

  /// [endOfCycle]: keeps the plan until the renewal; otherwise goes to the
  /// free plan now, with the refund of the remaining days (A1-j).
  Future<bool> cancelSubscription({
    required bool endOfCycle,
    required String keepTenantId,
  }) => _billingCommand('cancelSubscription', {
    'mode': endOfCycle ? 'END_OF_CYCLE' : 'NOW',
    'keepTenantId': keepTenantId,
  });

  /// An extra petshop leaves the paid cycle, with the refund of the
  /// remaining days, or comes back, with the proportional charge (A1-i).
  Future<bool> changeAccountTenant(String tenantId, {required bool add}) =>
      _billingCommand('changeAccountTenant', {
        'targetTenantId': tenantId,
        'action': add ? 'ADD' : 'REMOVE',
      });
  Future<List<SupportTicket>> loadSupportTickets() async =>
      ((await _companyQuery('getSupportRequests'))['items'] as List)
          .map(
            (item) =>
                SupportTicket.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
  Future<bool> _supportCommand(String name, Map<String, dynamic> input) =>
      runGuarded(() async {
        if (_pausedTarget != null) return _pausedCommand(name, input);
        final extras = _extras;
        if (extras == null) {
          throw const FormatException(
            'Suporte disponível apenas com conexão ao servidor.',
          );
        }
        await extras.companyCommand(name, input);
      });
  Future<bool> createSupportRequest(String subject, String message) =>
      _supportCommand('createSupportRequest', {
        'subject': subject,
        'message': message,
      });
  Future<bool> addSupportMessage(String id, String message) => _supportCommand(
    'addSupportMessage',
    {'supportRequestId': id, 'message': message},
  );

  Future<bool> signIn(String id, String password) =>
      _signInWith(() => _repository.signIn(id, password));

  Future<bool> _signInWith(Future<InternalUser> Function() authenticate) async {
    if (busy) return false;
    final epoch = ++_sessionEpoch;
    _activeFunction = null;
    _user = null;
    _company = null;
    _companies = const [];
    _clearCompanyData();
    final success = await runGuarded(() async {
      if (_closingSession != null) await _closingSession;
      await beforeSignIn?.call();
      late InternalUser user;
      _managerActivation = null;
      _staffActivation = null;
      _pausedAccess = const [];
      _pausedCompany = null;
      _billingNoticesSeen.clear();
      try {
        user = await authenticate();
      } on TeamLoginException catch (error) {
        if (epoch == _sessionEpoch) {
          loginRetryUntil = DateTime.now().add(
            Duration(milliseconds: error.retryAfterMs),
          );
        }
        rethrow;
      } on StaffActivationRequired catch (pending) {
        if (epoch == _sessionEpoch) _staffActivation = pending.profile;
        return;
      } on ManagerActivationRequired catch (pending) {
        if (epoch == _sessionEpoch) _managerActivation = pending.profile;
        return;
      } on AccessPausedRequired catch (paused) {
        if (epoch == _sessionEpoch) _pausedAccess = paused.companies;
        return;
      }
      if (epoch != _sessionEpoch) return;
      if (catalogOnly) {
        final companies = await _repository.getCompanies();
        if (epoch != _sessionEpoch) return;
        _companies = companies;
        if (companies.length == 1) {
          final selected = await _repository.selectCompany(companies.first.id);
          final services = selected.hasTeamOperations
              ? await _repository.getServices()
              : <PetService>[];
          if (epoch != _sessionEpoch) return;
          _company = companies.first;
          _user = selected;
          _services = services;
        }
      } else {
        _user = user;
        await _reload();
      }
    });
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return false;
    }
    if (success) _registerPush();
    return success;
  }

  Future<bool> selectCompany(String id) async {
    if (busy) return false;
    final epoch = ++_sessionEpoch;
    _activeFunction = null;
    _user = null;
    _company = null;
    _clearCompanyData();
    final success = await runGuarded(() async {
      final user = await _repository.selectCompany(id);
      final services = user.hasTeamOperations
          ? await _repository.getServices()
          : <PetService>[];
      if (epoch != _sessionEpoch) return;
      if (_persistent != null) _companies = _persistent!.authorizedCompanies;
      final previous = _companies.firstWhere((company) => company.id == id);
      _company = TeamCompany(
        id: previous.id,
        name: previous.name,
        recordNumber: previous.recordNumber,
        user: user,
        billing: previous.billing,
      );
      _companies = [
        for (final company in _companies)
          if (company.id == id) _company! else company,
      ];
      _user = user;
      _services = services;
    });
    if (!success && _persistent != null) {
      _companies = _persistent!.authorizedCompanies;
    }
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return false;
    }
    return success;
  }

  /// Drops the last operation message so a screen can start a new attempt
  /// without an older failure reappearing beside its own message.
  void clearError() => clearOperationState();

  void clearCompany() {
    ++_sessionEpoch;
    _activeFunction = null;
    _user = null;
    _company = null;
    _clearCompanyData();
    clearOperationState(notify: false);
    notifyListeners();
  }

  Future<bool> refreshServices() async {
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      try {
        final services = await _repository.getServices();
        if (epoch == _sessionEpoch) {
          _services = services;
          if (_persistent != null) {
            _companies = _persistent!.authorizedCompanies;
            _company = _companies.firstWhere(
              (value) => value.id == _company!.id,
            );
            _user = _company!.user;
          }
        }
      } catch (_) {
        if (epoch == _sessionEpoch) {
          _services = const [];
          _clearInvalidAccess();
        }
        rethrow;
      }
    });
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return false;
    }
    return success;
  }

  void signOut() {
    serviceQuoteChange = null;
    ++_sessionEpoch;
    _managerActivation = null;
    _staffActivation = null;
    _pausedAccess = const [];
    _pausedCompany = null;
    _billingNoticesSeen.clear();
    _activeFunction = null;
    _companies = const [];
    _company = null;
    _closingSession = _repository.signOut().catchError((Object _) {
      // The controller stays cleared. A new login explicitly signs out again.
    });
    _user = null;
    _customers = const [];
    _services = const [];
    _appointments = const [];
    _professionals = const [];
    _blocks = const [];
    _customersLoaded = false;
    _agendaLoaded = false;
    _agendaError = null;
    _customersError = null;
    _policy = SchedulingPolicy.initial;
    clearOperationState(notify: false);
    notifyListeners();
    onSignOut?.call();
  }

  Future<bool> _saveCustomerResult(
    Future<Customer> Function() operation,
  ) async {
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      final confirmed = await operation();
      if (epoch != _sessionEpoch) return;
      if (catalogOnly) {
        _customers = [
          ..._customers.where((value) => value.id != confirmed.id),
          confirmed,
        ];
        _customersLoaded = true;
      } else {
        await _reload();
      }
    });
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return false;
    }
    return success;
  }

  Future<bool> saveCustomer(Customer value) =>
      _saveCustomerResult(() => _repository.saveCustomer(value));
  Future<bool> savePet(String customerId, Pet value) =>
      _saveCustomerResult(() => _repository.savePet(customerId, value));

  /// Pets the petshop serves. Without the integration, or before the first
  /// read, every pet is served, as the server does without a saved rule.
  PetPolicy _petPolicy = const PetPolicy();
  PetPolicy get petPolicy => _petPolicy;
  bool get supportsPetService => _repository is PetServiceRepository;

  Future<void> _loadPetPolicy(int epoch) async {
    if (_repository is! PetServiceRepository) return;
    final value = await (_repository as PetServiceRepository).getPetPolicy();
    if (epoch == _sessionEpoch) _petPolicy = value;
  }

  Future<bool> refreshPetPolicy() =>
      _sessionMutation((epoch) => _loadPetPolicy(epoch));

  /// Saves the rule in the selected petshop and, when chosen, in other
  /// petshops of the same manager. Returns the names that failed.
  Future<List<String>?> savePetPolicy(
    PetPolicy value, {
    List<TeamCompany> alsoIn = const [],
  }) async {
    final failed = <String>[];
    final saved = await _sessionMutation((epoch) async {
      final repository = _repository as PetServiceRepository;
      final confirmed = await repository.savePetPolicy(value);
      if (epoch != _sessionEpoch) return;
      _petPolicy = confirmed;
      for (final company in alsoIn) {
        try {
          await repository.savePetPolicy(value, tenantId: company.id);
        } catch (_) {
          failed.add(company.name);
        }
        if (epoch != _sessionEpoch) return;
      }
      if (!catalogOnly) await _reload();
    });
    return saved ? failed : null;
  }

  /// "Não atender este pet". Returns how many appointments still to happen
  /// stay booked, or null when it failed.
  Future<int?> blockPet(String customerId, String petId, String reason) async {
    var count = 0;
    final saved = await _sessionMutation((epoch) async {
      count = await (_repository as PetServiceRepository).blockPet(
        customerId,
        petId,
        reason,
      );
      if (epoch == _sessionEpoch) await _reloadCustomers(epoch);
    });
    return saved ? count : null;
  }

  Future<bool> unblockPet(String customerId, String petId) => _sessionMutation((
    epoch,
  ) async {
    await (_repository as PetServiceRepository).unblockPet(customerId, petId);
    if (epoch == _sessionEpoch) await _reloadCustomers(epoch);
  });

  Future<void> _reloadCustomers(int epoch) async {
    final values = await _repository.getCustomers();
    if (epoch != _sessionEpoch) return;
    _customers = values;
    _customersLoaded = true;
  }

  Future<bool> saveService(PetService value, {PetService? original}) async {
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      final confirmed = await _repository.saveService(
        value,
        original: original,
      );
      if (epoch != _sessionEpoch) return;
      if (catalogOnly) {
        final index = _services.indexWhere((item) => item.id == confirmed.id);
        _services = [..._services];
        if (index < 0) {
          _services.add(confirmed);
        } else {
          _services[index] = confirmed;
        }
      } else {
        await _reload();
      }
    });
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return false;
    }
    return success;
  }

  Future<bool> _sessionMutation(
    Future<void> Function(int epoch) operation,
  ) async {
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      try {
        await operation(epoch);
      } catch (_) {
        if (epoch == _sessionEpoch) _clearInvalidAccess();
        rethrow;
      }
    });
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return false;
    }
    return success;
  }

  Future<bool> saveProfessional(Professional value) =>
      _sessionMutation((epoch) async {
        final confirmed = await _repository.saveProfessional(value);
        if (epoch != _sessionEpoch) return;
        if (catalogOnly) {
          _professionals = [
            ..._professionals.where((item) => item.id != confirmed.id),
            confirmed,
          ];
        } else {
          await _reload();
        }
      });
  Future<bool> saveBlock(ScheduleBlock value) =>
      _sessionMutation((epoch) async {
        final confirmed = await _repository.saveBlock(value);
        if (epoch != _sessionEpoch) return;
        if (catalogOnly) {
          _blocks = [
            ..._blocks.where((item) => item.id != confirmed.id),
            confirmed,
          ];
        } else {
          await _reload();
        }
      });
  Future<bool> removeBlock(String id) => _sessionMutation((epoch) async {
    await _repository.removeBlock(id);
    if (epoch != _sessionEpoch) return;
    if (catalogOnly) {
      _blocks = _blocks.where((item) => item.id != id).toList();
    } else {
      await _reload();
    }
  });
  Future<bool> updateAppointmentNotes(String id, String notes) =>
      _sessionMutation((epoch) async {
        final target = _repository;
        if (target is! AppointmentNotesRepository) {
          throw const FormatException('Atualize a integração de observações.');
        }
        final confirmed = await (target as AppointmentNotesRepository)
            .updateAppointmentNotes(id, notes);
        if (epoch != _sessionEpoch) return;
        _appointments = [
          ..._appointments.where((item) => item.id != confirmed.id),
          confirmed,
        ];
      });
  Map<String, dynamic>? serviceQuoteChange;
  Future<bool> saveAppointment(Appointment value) =>
      _sessionMutation((epoch) async {
        serviceQuoteChange = null;
        late Appointment confirmed;
        try {
          confirmed = await _repository.saveAppointment(value);
        } on ServiceQuoteChangedException catch (changed) {
          if (epoch == _sessionEpoch) serviceQuoteChange = changed.quote;
          rethrow;
        }
        if (epoch != _sessionEpoch) return;
        if (catalogOnly) {
          _appointments = [
            ..._appointments.where((item) => item.id != confirmed.id),
            confirmed,
          ];
          _agendaLoaded = true;
        } else {
          await _reload();
        }
      });
  Future<bool> updatePetStatus(
    String id,
    String petId,
    AppointmentStatus status,
  ) => _sessionMutation((epoch) async {
    final target = _repository;
    if (target is! PetExecutionRepository) {
      throw const FormatException(
        'A execução individual exige a integração atualizada.',
      );
    }
    final confirmed = await (target as PetExecutionRepository).updatePetStatus(
      id,
      petId,
      status,
    );
    if (epoch != _sessionEpoch) return;
    _appointments = [
      ..._appointments.where((item) => item.id != confirmed.id),
      confirmed,
    ];
  });
  Future<bool> updateStatus(String id, AppointmentStatus status) =>
      _sessionMutation((epoch) async {
        final confirmed = await _repository.updateAppointmentStatus(id, status);
        if (epoch != _sessionEpoch) return;
        if (catalogOnly) {
          _appointments = [
            ..._appointments.where((item) => item.id != confirmed.id),
            confirmed,
          ];
        } else {
          await _reload();
        }
      });
  Future<bool> refreshAgenda() async {
    final epoch = _sessionEpoch;
    final success = await runGuarded(() async {
      try {
        final appointments = await _repository.getAppointments();
        if (epoch != _sessionEpoch) return;
        _appointments = appointments;
        _agendaLoaded = true;
        try {
          final professionals = await _repository.getProfessionals();
          if (epoch != _sessionEpoch) return;
          _professionals = professionals;
        } on NetworkException {
          /* The appointment snapshot can still be consulted. */
        }
        try {
          final blocks = await _repository.getBlocks();
          if (epoch != _sessionEpoch) return;
          _blocks = blocks;
        } on NetworkException {
          /* Unavailable resources are not presented as new downloads. */
        }
      } catch (_) {
        if (epoch == _sessionEpoch) _clearInvalidAccess();
        rethrow;
      }
    });
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return false;
    }
    _agendaError = success ? null : error;
    return success;
  }

  Future<List<AvailableSlot>?> availableSlots(
    String customerId,
    List<AppointmentItem> items,
    DateTime day, {
    String? appointmentId,
  }) async {
    final epoch = _sessionEpoch;
    List<AvailableSlot>? result;
    await runGuarded(() async {
      result = await _schedule.getAvailableSlots(
        customerId,
        items,
        day,
        appointmentId: appointmentId,
      );
    });
    if (epoch != _sessionEpoch) {
      clearOperationState();
      return null;
    }
    return result;
  }

  Future<bool> loadSchedulingPolicy() => _sessionMutation((epoch) async {
    final value = await _schedule.getSchedulingPolicy();
    if (epoch == _sessionEpoch) _policy = value;
  });
  Future<bool> saveSchedulingPolicy(SchedulingPolicy value) =>
      _sessionMutation((epoch) async {
        final confirmed = await _schedule.saveSchedulingPolicy(value);
        if (epoch == _sessionEpoch) _policy = confirmed;
      });

  /// Live refresh of gestão/atendimento: the server moved the team signal of
  /// the open petshop. Customers, services, agenda, professionals and blocks
  /// are read again without loading state; a failure waits for the next
  /// signal or a manual refresh.
  @override
  LiveSignalSource? get liveSource => _repository is LiveSignalsAware
      ? (_repository as LiveSignalsAware).liveSignals
      : null;
  @override
  Iterable<String> livePaths(String uid) {
    final company = _company, user = _user;
    if (company == null || user == null || !user.hasTeamOperations) {
      return const [];
    }
    return [LiveSignalPaths.team(company.id)];
  }

  /// Live refresh for a screen that shows several petshops at once, as the
  /// all-companies view: the caller watches the team signal of each one and
  /// disposes it. Null without live signals (offline test doubles).
  LiveRefresh? followCompanies(void Function() onChange) {
    final source = liveSource;
    if (source == null || source.uid == null) return null;
    return LiveRefresh(source: source, onChange: onChange);
  }

  /// Back to the app: the reading of the live refresh, in parallel and
  /// without loading state, so the screen keeps answering taps while it
  /// runs. A revoked access still ends the session.
  Future<bool> refreshOnResume() async {
    if (user == null) return false;
    final epoch = _sessionEpoch;
    final done = await liveRefresh();
    if (epoch != _sessionEpoch) return false;
    if (!done) {
      _clearInvalidAccess();
      return false;
    }
    // The roles of each petshop come back with the reading, as in
    // refreshServices.
    final persistent = _persistent, current = _company;
    if (persistent != null && current != null) {
      final companies = persistent.authorizedCompanies;
      final match = companies.where((value) => value.id == current.id);
      if (match.isNotEmpty) {
        _companies = companies;
        _company = match.first;
        _user = _company!.user;
        notifyListeners();
      }
    }
    return true;
  }

  @override
  Future<void> liveReload() async {
    final epoch = _sessionEpoch;
    await _reload();
    if (epoch != _sessionEpoch) return;
    _agendaError = null;
    _customersError = null;
    await refreshTutorLinkSummary();
  }

  Future<void> _reload() async {
    final epoch = _sessionEpoch;
    final values = await Future.wait([
      _repository.getCustomers(),
      _repository.getServices(),
      _repository.getAppointments(),
      _repository.getProfessionals(),
      _repository.getBlocks(),
    ]);
    if (epoch != _sessionEpoch) return;
    _customers = values[0] as List<Customer>;
    _services = values[1] as List<PetService>;
    _appointments = values[2] as List<Appointment>;
    _professionals = values[3] as List<Professional>;
    _blocks = values[4] as List<ScheduleBlock>;
    // The rule moves the team signal too; without connection the last rule read stays.
    try {
      await _loadPetPolicy(epoch);
    } catch (_) {}
  }

  Future<List<CompanyDriver>> getDrivers() async {
    final epoch = _sessionEpoch;
    final result = await (_repository as TransportManagementRepository)
        .getDrivers();
    if (epoch != _sessionEpoch) {
      throw const FormatException('Sessão encerrada.');
    }
    return result;
  }

  Future<bool> createTransport(TransportRequest request) =>
      _sessionMutation((epoch) async {
        await (_repository as TransportManagementRepository).createTransport(
          request,
        );
      });
  Future<T> _transportRead<T>(
    Future<T> Function(TransportManagementRepository) action,
  ) async {
    final epoch = _sessionEpoch;
    final result = await action(_repository as TransportManagementRepository);
    if (epoch != _sessionEpoch) {
      throw const FormatException('Sessão ou empresa alterada.');
    }
    return result;
  }

  bool get supportsTransportReview =>
      _repository is TransportManagementRepository;

  Future<List<ManagedTransport>> getTransports({String? appointmentId}) =>
      _transportRead((r) => r.getTransports(appointmentId: appointmentId));

  /// Live position of the driver of a transport on the way.
  bool get supportsDriverPosition => _repository is DriverPositionRepository;
  Future<DriverPosition> transportLocation(String transportId) =>
      _transportRead(
        (r) => (r as DriverPositionRepository).transportLocation(transportId),
      );

  /// Driving minutes between the typed addresses, or null when the route
  /// cannot be found now (the conflict check then compares equal times).
  Future<int?> estimateTrip(
    Map<String, String> origin,
    Map<String, String> destination,
  ) async {
    if (_repository is! TripEstimateRepository) return null;
    try {
      return await _transportRead(
        (r) => (r as TripEstimateRepository).estimateTripMinutes(
          origin,
          destination,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<TransportConflictPreview> transportConflicts(
    String driverUid,
    DateTime at,
    int? duration, {
    String? excludeId,
    String? appointmentId,
  }) => _transportRead(
    (r) => r.conflicts(
      driverUid,
      at,
      duration,
      excludeId: excludeId,
      appointmentId: appointmentId,
    ),
  );
  Future<bool> reassignTransport(
    ManagedTransport t,
    String driverUid,
    String reason,
    bool custodyConfirmed,
    String acknowledgement,
  ) => _sessionMutation((epoch) async {
    await (_repository as TransportManagementRepository).reassign(
      t,
      driverUid,
      reason,
      custodyConfirmed,
      acknowledgement,
    );
  });
  Future<bool> manageTransportIncident(
    String transportId,
    String incidentId,
    String status,
    String message,
  ) => _sessionMutation((epoch) async {
    await (_repository as TransportManagementRepository).manageIncident(
      transportId,
      incidentId,
      status,
      message,
    );
  });
  Future<T> _bookingRead<T>(
    Future<T> Function(TransportBookingRepository) action,
  ) async {
    final epoch = _sessionEpoch, tenant = company?.id;
    final result = await action(_repository as TransportBookingRepository);
    if (epoch != _sessionEpoch || tenant != company?.id) {
      throw const FormatException('Sessão ou empresa alterada.');
    }
    return result;
  }

  Future<Map<String, dynamic>> bookingPolicy() =>
      _bookingRead((r) => r.bookingPolicy());
  Future<List<Map<String, dynamic>>> searchBookingAddress(String query) =>
      _bookingRead((r) => r.searchBookingAddress(query));
  Future<bool> saveBookingPolicy(Map<String, dynamic> policy) =>
      _sessionMutation((epoch) async {
        await (_repository as TransportBookingRepository).saveBookingPolicy(
          policy,
        );
      });
  Future<List<Map<String, dynamic>>> bookingRequests() =>
      _bookingRead((r) => r.bookingRequests());
  Future<bool> decideBookingRequest(Map<String, dynamic> input) =>
      _sessionMutation((epoch) async {
        await (_repository as TransportBookingRepository).decideBookingRequest(
          input,
        );
      });
}

/// Notices of management/attendance, read through the selected petshop.
class _TeamNotices implements RoleNoticesSource {
  _TeamNotices(this._controller);
  final AppController _controller;
  @override
  Future<Map<String, dynamic>> roleNotices(String tenantId) =>
      _controller._companyQuery('getNotices', {'role': 'TEAM'});
  @override
  Future<void> markRoleNoticesSeen(String tenantId) async {
    await _controller._companyQuery('markNoticesSeen', {'role': 'TEAM'});
  }
}
