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

import 'package:caopanheiro_core/caopanheiro_core.dart';

import '../domain/models.dart';
import '../domain/models/team_company.dart';
import '../domain/repositories/persistent_catalog_repository.dart';
import 'sql_catalog_store.dart';
import 'team_json.dart';
import '../domain/repositories/scheduling_repository.dart';
import '../domain/models/scheduling_policy.dart';
import '../domain/repositories/customer_link_repository.dart';
import '../domain/repositories/tutor_join_link_repository.dart';

class OfflineCatalogRepository
    implements
        PersistentCatalogRepository,
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
        TransportBookingRepository,
        TeamExtrasRepository,
        PausedAccessRepository,
        ScreenTipsRepository,
        LiveSignalsAware,
        NetworkProblemSource {
  OfflineCatalogRepository(this.remote, this.store);

  /// Tip marks live in the account on the server; the SQL cache keeps none,
  /// so a start without connection offers no tip.
  ScreenTipsRepository? get _tipsRemote {
    final Object source = remote;
    return source is ScreenTipsRepository ? source : null;
  }

  @override
  ScreenTips? get screenTips => _tipsRemote?.screenTips;
  @override
  Future<void> markScreenTipsSeen(String screen) async =>
      _tipsRemote?.markScreenTipsSeen(screen);
  @override
  Future<void> turnOffScreenTips() async => _tipsRemote?.turnOffScreenTips();
  @override
  Future<void> resetScreenTips() async => _tipsRemote?.resetScreenTips();

  /// Live signals come from the server connection; the SQL cache has none.
  @override
  LiveSignalSource? get liveSignals {
    final Object source = remote;
    return source is LiveSignalsAware ? source.liveSignals : null;
  }

  TeamExtrasRepository? get _extrasRemote {
    final Object source = remote;
    return source is TeamExtrasRepository && source.extrasAvailable
        ? source
        : null;
  }

  @override
  bool get extrasAvailable => _extrasRemote != null;
  @override
  List<String> get signInProviders =>
      _extrasRemote?.signInProviders ?? const [];
  @override
  Future<void> linkGoogle() {
    final extras = _extrasRemote;
    if (extras == null) {
      throw const FormatException('Vínculo com Google indisponível.');
    }
    if (offline) {
      throw NetworkException('Vincular o Google exige conexão.', _problem);
    }
    return extras.linkGoogle();
  }

  Future<T> _extrasOnline<T>(
    Future<T> Function(TeamExtrasRepository) operation,
  ) async {
    final epoch = _epoch, tenant = _tenant;
    _check(epoch);
    final extras = _extrasRemote;
    if (extras == null) throw const FormatException('Recurso indisponível.');
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    if (offline) {
      throw NetworkException('Esta consulta exige conexão.', _problem);
    }
    final result = await _authorized(() => operation(extras));
    _check(epoch);
    if (tenant != _tenant) throw const FormatException('Petshop alterado.');
    return result;
  }

  @override
  Future<Map<String, dynamic>> companyQuery(
    String name, [
    Map<String, dynamic> input = const {},
  ]) => _extrasOnline((extras) => extras.companyQuery(name, input));

  /// Paused petshops (E2) go straight to the server: nothing is cached.
  @override
  List<PausedCompany> get pausedCompanies => remote is PausedAccessRepository
      ? (remote as PausedAccessRepository).pausedCompanies
      : const [];
  @override
  Future<Map<String, dynamic>> pausedQuery(
    String tenantId,
    String name, [
    Map<String, dynamic> input = const {},
  ]) => remote is PausedAccessRepository
      ? (remote as PausedAccessRepository).pausedQuery(tenantId, name, input)
      : throw const FormatException('Recurso indisponível.');
  @override
  Future<Map<String, dynamic>> pausedCommand(
    String tenantId,
    String name,
    Map<String, dynamic> input,
  ) => remote is PausedAccessRepository
      ? (remote as PausedAccessRepository).pausedCommand(tenantId, name, input)
      : throw const FormatException('Recurso indisponível.');
  @override
  Future<Map<String, dynamic>> companyCommand(
    String name,
    Map<String, dynamic> input,
  ) => _extrasOnline((extras) => extras.companyCommand(name, input));
  @override
  bool get hasPendingCommands =>
      remote is WorkforceRepository &&
      (remote as WorkforceRepository).hasPendingCommands;
  @override
  Future<CompanyViewPage> companyView({
    required String tenantId,
    required TenantRole role,
    required String resource,
    String? cursor,
  }) async {
    final epoch = _epoch;
    _check(epoch);
    if (!_companies.any((company) => company.id == tenantId)) {
      throw const FormatException('Empresa indisponível.');
    }
    final source = remote;
    if (source is! CompanyViewRepository) {
      throw const FormatException('Consulta de empresas indisponível.');
    }
    try {
      final result = await (source as CompanyViewRepository).companyView(
        tenantId: tenantId,
        role: role,
        resource: resource,
        cursor: cursor,
      );
      _check(epoch);
      return result;
    } on SessionAccessException {
      _check(epoch);
      final uid = _uid!;
      try {
        await _write(epoch, () => store.invalidateCompany(uid, tenantId));
      } catch (_) {
        await _deny(epoch);
      }
      rethrow;
    }
  }

  final AuthenticatedCatalogRepository remote;
  final SqlCatalogStore store;
  int _epoch = 0;
  String? _uid;
  String? _tenant;
  List<TeamCompany> _companies = const [];
  Future<void> _disk = Future.value();
  bool _offline = false;
  NetworkProblem? _offlineProblem;
  final Set<String> _offlineResources = {};
  final Map<String, DateTime> _resourceTimes = {};
  @override
  DateTime? get agendaUpdatedAt => _resourceTimes['appointments'];
  bool _invalidated = false;
  DateTime? _updated;
  DateTime? _customersUpdated;
  @override
  DateTime? get customersUpdatedAt => _customersUpdated;
  String? _localWarning;
  @override
  String? get localWarning => _localWarning;
  @override
  bool get offline => _offline || _offlineResources.isNotEmpty;

  /// Why the local copy is in use, otherwise the latest reason of the server
  /// connection.
  @override
  NetworkProblem? get lastNetworkProblem {
    final Object source = remote;
    return _offlineProblem ??
        (source is NetworkProblemSource ? source.lastNetworkProblem : null);
  }

  NetworkProblem get _problem =>
      lastNetworkProblem ?? NetworkProblem.serverUnreachable;
  @override
  bool get accessInvalidated => _invalidated;
  @override
  DateTime? get catalogUpdatedAt => _updated;
  @override
  List<TeamCompany> get authorizedCompanies => _companies;
  @override
  List<ManagementCompany> get managementCompanies =>
      _uid != null &&
          _uid == remote.currentUid &&
          !_invalidated &&
          !offline &&
          remote is ManagementCompanyDirectory
      ? (remote as ManagementCompanyDirectory).managementCompanies
      : const [];

  Future<T> _diskOperation<T>(Future<T> Function() operation) {
    final result = _disk.then((_) => operation());
    _disk = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  void _check(int epoch) {
    if (epoch != _epoch || _uid == null || _uid != remote.currentUid) {
      throw const FormatException('Sessão encerrada.');
    }
  }

  Future<void> _write(int epoch, Future<void> Function() operation) =>
      _diskOperation(() async {
        _check(epoch);
        await operation();
      });

  Future<void> _deny(int epoch) async {
    if (epoch != _epoch) return;
    ++_epoch;
    _invalidated = true;
    _companies = const [];
    _uid = null;
    _tenant = null;
    _offlineResources.clear();
    _resourceTimes.clear();
    _updated = null;
    _customersUpdated = null;
    await _diskOperation(store.clear);
  }

  Future<T> _workforceOnline<T>(
    Future<T> Function(WorkforceRepository) operation,
  ) async {
    final epoch = _epoch, tenant = _tenant;
    _check(epoch);
    if (offline) throw const FormatException('Alterar funções exige conexão.');
    final result = await _authorized(
      () => operation(remote as WorkforceRepository),
    );
    _check(epoch);
    if (tenant != _tenant) throw const FormatException('Petshop alterado.');
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> workforceMembers() =>
      _workforceOnline((r) => r.workforceMembers());
  @override
  Future<void> saveWorkforceRoles(Map<String, dynamic> input) =>
      _invalidateProfessionalsAfter(
        () => _workforceOnline((r) => r.saveWorkforceRoles(input)),
      );

  @override
  Future<Customer> unlinkCustomerAccount(String customerId) => _mutateResource(
    'customers',
    () =>
        (remote as CustomerUnlinkRepository).unlinkCustomerAccount(customerId),
    customerToJson,
  );
  @override
  Future<void> deleteOwnAccount(String password) async {
    final epoch = _epoch;
    _check(epoch);
    if (offline) {
      throw NetworkException('Conecte-se para excluir sua conta.', _problem);
    }
    await (remote as AccountDeletionRepository).deleteOwnAccount(password);
    if (epoch != _epoch ||
        remote.currentUid != null && remote.currentUid != _uid) {
      throw const FormatException('Sessão alterada.');
    }
    // Auth can clear the deleted identity before the response reaches the app.
    await signOut();
  }

  Future<void> _invalidateProfessionalsAfter(
    Future<void> Function() command,
  ) async {
    final epoch = _epoch, uid = _uid, tenant = _tenant;
    await command();
    _check(epoch);
    if (uid == null || tenant == null || tenant != _tenant) return;
    _offlineResources.remove('professionals');
    _resourceTimes.remove('professionals');
    try {
      await _write(
        epoch,
        () => store.invalidateResource(uid, tenant, 'professionals'),
      );
    } catch (_) {
      _check(epoch);
      _localWarning =
          'Acesso atualizado no servidor. Conecte-se para renovar os profissionais.';
    }
  }

  StaffLinkRepository get _links => remote as StaffLinkRepository;
  @override
  bool get invitationEmailVerified => _links.invitationEmailVerified;
  @override
  Future<String> createStaffLink(Map<String, dynamic> input) =>
      _staffOnline(() => _links.createStaffLink(input));
  @override
  Future<void> unlinkWorkforceMember(Map<String, dynamic> input) =>
      _invalidateProfessionalsAfter(
        () => _staffOnline(() => _links.unlinkWorkforceMember(input)),
      );
  @override
  Future<Map<String, dynamic>> inspectStaffLink(StaffLink link) =>
      _links.inspectStaffLink(link);
  @override
  Future<void> authenticateStaffLink(
    StaffLink link, {
    required String email,
    required String password,
    required bool createAccount,
  }) async {
    await signOut();
    await _links.authenticateStaffLink(
      link,
      email: email,
      password: password,
      createAccount: createAccount,
    );
  }

  @override
  Future<void> sendLinkVerification() => _links.sendLinkVerification();
  @override
  Future<void> acceptStaffLink(
    StaffLink link, {
    required String name,
    required String phone,
    String? specialty,
  }) => _links.acceptStaffLink(
    link,
    name: name,
    phone: phone,
    specialty: specialty,
  );

  StaffInvitationRepository get _staff {
    if (remote is! StaffInvitationRepository) {
      throw const FormatException('Convites indisponíveis.');
    }
    return remote as StaffInvitationRepository;
  }

  Future<T> _staffOnline<T>(Future<T> Function() operation) async {
    final epoch = _epoch, tenant = _tenant;
    _check(epoch);
    if (offline) {
      throw const FormatException('Gerenciar convites exige conexão.');
    }
    final result = await _authorized(operation);
    _check(epoch);
    if (tenant != _tenant) throw const FormatException('Petshop alterado.');
    return result;
  }

  @override
  Future<void> inviteWorkforceUser(Map<String, dynamic> input) =>
      _staffOnline(() => _staff.inviteWorkforceUser(input));
  @override
  Future<void> revokeWorkforceInvitation(String userId) =>
      _staffOnline(() => _staff.revokeWorkforceInvitation(userId));
  @override
  Future<void> sendStaffVerification() => _staff.sendStaffVerification();
  @override
  Future<void> completeStaffActivation({
    required String tenantId,
    required String name,
    required String phone,
  }) => _staff.completeStaffActivation(
    tenantId: tenantId,
    name: name,
    phone: phone,
  );

  ManagerActivationRepository get _activation {
    if (remote is! ManagerActivationRepository) {
      throw const FormatException('Primeiro acesso indisponível.');
    }
    return remote as ManagerActivationRepository;
  }

  @override
  Future<bool> hasManagerInvitation(String email) =>
      (remote as TeamLoginRepository).hasManagerInvitation(email);
  @override
  Future<void> resendManagerInvitation(String email) =>
      (remote as TeamLoginRepository).resendManagerInvitation(email);
  @override
  Future<void> requestManagerPassword(String email) =>
      _activation.requestManagerPassword(email);
  @override
  Future<ManagerActivation> beginManagerActivation(
    String email,
    String password,
  ) async {
    await signOut(); // No access snapshot may survive an activation-only session.
    return _activation.beginManagerActivation(email, password);
  }

  @override
  Future<void> sendManagerVerification() =>
      _activation.sendManagerVerification();
  @override
  Future<void> completeManagerActivation({
    required String tenantId,
    required String name,
    required String phone,
    required String companyPhone,
    required String city,
    required String state,
  }) => _activation.completeManagerActivation(
    tenantId: tenantId,
    name: name,
    phone: phone,
    companyPhone: companyPhone,
    city: city,
    state: state,
  );

  @override
  Future<bool> restoreSession() async {
    final epoch = ++_epoch;
    final uid = remote.currentUid;
    final cachedUid = await _diskOperation(() => store.sessionUid);
    if (epoch != _epoch) return false;
    if (uid == null || cachedUid != uid) {
      await _diskOperation(store.clear);
      return false;
    }
    _uid = uid;
    _invalidated = false;
    await getCompanies(); // Only network failures permit the previous access.
    return _companies.isNotEmpty;
  }

  @override
  Future<InternalUser> signIn(String identifier, String password) async {
    final epoch = ++_epoch;
    _uid = null;
    _tenant = null;
    _offlineResources.clear();
    _resourceTimes.clear();
    _companies = const [];
    _updated = null;
    _customersUpdated = null;
    _offline = false;
    _offlineProblem = null;
    _invalidated = false;
    await _diskOperation(store.clear);
    final user = await remote.signIn(identifier, password);
    if (epoch != _epoch) throw const FormatException('Sessão encerrada.');
    _uid = remote.currentUid;
    _check(epoch);
    await getCompanies();
    return user;
  }

  /// Same local preparation of the password sign-in; only the proof differs.
  @override
  Future<InternalUser> signInWithGoogle() async {
    final extras = _extrasRemote;
    if (extras == null) {
      throw const FormatException('Entrada com Google indisponível.');
    }
    final epoch = ++_epoch;
    _uid = null;
    _tenant = null;
    _offlineResources.clear();
    _resourceTimes.clear();
    _companies = const [];
    _updated = null;
    _customersUpdated = null;
    _offline = false;
    _offlineProblem = null;
    _invalidated = false;
    await _diskOperation(store.clear);
    final user = await extras.signInWithGoogle();
    if (epoch != _epoch) throw const FormatException('Sessão encerrada.');
    _uid = remote.currentUid;
    _check(epoch);
    await getCompanies();
    return user;
  }

  @override
  Future<List<TeamCompany>> getCompanies() async {
    final epoch = _epoch;
    _check(epoch);
    final uid = _uid!;
    try {
      final companies = await remote.getCompanies();
      _check(epoch);
      if (companies.isEmpty) {
        throw const FormatException('Nenhuma empresa autorizada.');
      }
      await _write(epoch, () => store.replaceAccess(uid, companies));
      _check(epoch);
      _companies = companies;
      _offline = false;
      return companies;
    } on NetworkException catch (error) {
      _check(epoch);
      _offlineProblem = error.problem;
      final companies = await _diskOperation(() => store.companies(uid));
      _check(epoch);
      if (companies.isEmpty) rethrow;
      _offline = true;
      return _companies = companies;
    } on AppOutdatedException {
      // Only an update solves it; the access and the local copy stay.
      rethrow;
    } on FormatException {
      await _deny(epoch);
      rethrow;
    }
  }

  @override
  Future<InternalUser> selectCompany(String id) async {
    final epoch = ++_epoch;
    _tenant = null;
    _offlineResources.clear();
    _resourceTimes.clear();
    _updated = null;
    _customersUpdated = null;
    final companies = await getCompanies();
    _check(epoch);
    if (!companies.any((company) => company.id == id)) {
      throw const FormatException('Vínculo com a empresa indisponível.');
    }
    try {
      if (!_offline) await remote.selectCompany(id);
      _check(epoch);
      _tenant = id;
      return companies.firstWhere((company) => company.id == id).user;
    } on NetworkException catch (error) {
      _check(epoch);
      _offlineProblem = error.problem;
      _offline = true;
      _tenant = id;
      return companies.firstWhere((company) => company.id == id).user;
    } on AppOutdatedException {
      // Only an update solves it; the access and the local copy stay.
      rethrow;
    } on FormatException {
      await _deny(epoch);
      rethrow;
    }
  }

  @override
  Future<List<PetService>> getServices() async {
    final epoch = _epoch;
    _check(epoch);
    final uid = _uid!;
    final tenant = _tenant;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    try {
      final companies = await getCompanies();
      if (!companies.any((company) => company.id == tenant)) {
        await _deny(epoch);
        throw const FormatException('Acesso à empresa removido.');
      }
      if (_offline) throw NetworkException(null, _problem);
      await remote.selectCompany(tenant);
      final services = await remote.getServices();
      _check(epoch);
      if (tenant != _tenant) throw const FormatException('Empresa alterada.');
      final time = DateTime.now().toUtc();
      await _write(
        epoch,
        () => store.replaceCatalog(uid, tenant, services, time),
      );
      _check(epoch);
      _updated = time;
      _offlineResources.remove('services');
      _localWarning = null;
      _offline = false;
      return services;
    } on NetworkException catch (error) {
      _check(epoch);
      _offlineProblem = error.problem;
      final cached = await _diskOperation(() => store.catalog(uid, tenant));
      _check(epoch);
      if (tenant != _tenant) throw const FormatException('Empresa alterada.');
      if (cached == null) {
        throw NetworkException(
          'Esta empresa ainda não tem catálogo salvo neste aparelho. Conecte-se para consultar.',
          _problem,
        );
      }
      _offline = true;
      _updated = cached.updatedAt;
      _offlineResources.add('services');
      return cached.services;
    } on AppOutdatedException {
      // Only an update solves it; the access and the local copy stay.
      rethrow;
    } on FormatException {
      await _deny(epoch);
      rethrow;
    }
  }

  @override
  Future<PetService> saveService(
    PetService service, {
    PetService? original,
  }) async {
    final epoch = _epoch;
    _check(epoch);
    if (_offline) {
      throw NetworkException(
        'Conecte-se e atualize o catálogo para alterar serviços.',
        _problem,
      );
    }
    final uid = _uid!;
    final tenant = _tenant;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    final companies = await getCompanies();
    _check(epoch);
    if (!companies.any((company) => company.id == tenant)) {
      await _deny(epoch);
      throw const FormatException('Acesso à empresa removido.');
    }
    if (_offline) {
      throw NetworkException(
        'Conecte-se e atualize o catálogo para alterar serviços.',
        _problem,
      );
    }
    final confirmed = await _authorized(
      () => remote.saveService(service, original: original),
    );
    _check(epoch);
    if (tenant != _tenant) throw const FormatException('Empresa alterada.');
    // No local mutation is made until the server has confirmed this command.
    try {
      await _write(epoch, () => store.saveConfirmed(uid, tenant, confirmed));
    } catch (_) {
      _check(epoch);
      _localWarning =
          'Salvo no servidor. A cópia offline não pôde ser atualizada. Atualize o catálogo.';
      _updated = null;
      // Do not report a confirmed server command as failed, inviting a retry.
      try {
        await _diskOperation(store.clear);
      } catch (_) {
        // Keep the confirmed result even if device storage itself has failed.
      }
    }
    _check(epoch);
    return confirmed;
  }

  @override
  Future<void> signOut() async {
    ++_epoch;
    _uid = null;
    _tenant = null;
    _offlineResources.clear();
    _resourceTimes.clear();
    _companies = const [];
    _offline = false;
    _offlineProblem = null;
    _updated = null;
    _customersUpdated = null;
    _localWarning = null;
    try {
      await _diskOperation(store.clear);
    } finally {
      await remote.signOut();
    }
  }

  @override
  Future<List<Customer>> getCustomers() async {
    final epoch = _epoch;
    _check(epoch);
    final uid = _uid!;
    final tenant = _tenant;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    try {
      final companies = await getCompanies();
      if (!companies.any((value) => value.id == tenant)) {
        await _deny(epoch);
        throw const FormatException('Acesso à empresa removido.');
      }
      if (_offline) throw NetworkException(null, _problem);
      await remote.selectCompany(tenant);
      final result = await remote.getCustomers();
      _check(epoch);
      if (tenant != _tenant) throw const FormatException('Empresa alterada.');
      final time = DateTime.now().toUtc();
      await _write(
        epoch,
        () => store.replaceResource(
          uid,
          tenant,
          'customers',
          result.map(customerToJson).toList(),
          time,
        ),
      );
      _check(epoch);
      _customersUpdated = time;
      _offline = false;
      _offlineResources.remove('customers');
      return result;
    } on NetworkException catch (error) {
      _check(epoch);
      _offlineProblem = error.problem;
      final cached = await _diskOperation(
        () => store.resource(uid, tenant, 'customers'),
      );
      _check(epoch);
      if (tenant != _tenant) throw const FormatException('Empresa alterada.');
      if (cached == null) {
        throw NetworkException(
          'Os clientes desta empresa ainda não foram salvos neste aparelho. Conecte-se e atualize.',
          _problem,
        );
      }
      _offline = true;
      _customersUpdated = cached.updatedAt;
      _offlineResources.add('customers');
      return cached.items.map(customerFromJson).toList();
    } on AppOutdatedException {
      // Only an update solves it; the access and the local copy stay.
      rethrow;
    } on FormatException {
      await _deny(epoch);
      rethrow;
    }
  }

  Future<void> _cacheCustomer(int epoch, String tenant, Customer value) async {
    _check(epoch);
    try {
      await _write(
        epoch,
        () => store.patchResourceItem(
          _uid!,
          tenant,
          'customers',
          customerToJson(value),
        ),
      );
    } catch (_) {
      _check(epoch);
      _customersUpdated = null;
      _localWarning =
          'Salvo no servidor. Atualize os clientes para renovar a cópia offline.';
      try {
        await _diskOperation(
          () => store.invalidateResource(_uid!, tenant, 'customers'),
        );
      } catch (_) {}
    }
  }

  @override
  Future<List<Appointment>> getAppointments() => _readResource(
    'appointments',
    remote.getAppointments,
    appointmentFromJson,
    appointmentToJson,
  );
  @override
  Future<List<Professional>> getProfessionals() => _readResource(
    'professionals',
    remote.getProfessionals,
    professionalFromJson,
    professionalToJson,
  );
  @override
  Future<List<ScheduleBlock>> getBlocks() =>
      _readResource('blocks', remote.getBlocks, blockFromJson, blockToJson);
  @override
  Future<Customer> saveCustomer(Customer value) async {
    final epoch = _epoch;
    _check(epoch);
    final tenant = _tenant;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    if (offline) {
      throw NetworkException('Cadastro e edição exigem conexão.', _problem);
    }
    final confirmed = await _authorized(() => remote.saveCustomer(value));
    _check(epoch);
    if (tenant != _tenant) throw const FormatException('Empresa alterada.');
    await _cacheCustomer(epoch, tenant, confirmed);
    return confirmed;
  }

  @override
  Future<Customer> savePet(String customer, Pet value) async {
    final epoch = _epoch;
    _check(epoch);
    final tenant = _tenant;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    if (offline) {
      throw NetworkException('Cadastro e edição exigem conexão.', _problem);
    }
    final confirmed = await _authorized(() => remote.savePet(customer, value));
    _check(epoch);
    if (tenant != _tenant) throw const FormatException('Empresa alterada.');
    await _cacheCustomer(epoch, tenant, confirmed);
    return confirmed;
  }

  @override
  Future<String> createTutorLink(String customerId) async {
    final epoch = _epoch;
    _check(epoch);
    if (offline) throw NetworkException('O vínculo exige conexão.', _problem);
    if (remote is! CustomerLinkRepository) {
      throw const FormatException('Vínculo indisponível.');
    }
    final result = await _authorized(
      () => (remote as CustomerLinkRepository).createTutorLink(customerId),
    );
    _check(epoch);
    return result;
  }

  /// The fixed invite link lives only on the server: no cache, connection
  /// required, as the individual invite.
  Future<T> _joinLink<T>(
    Future<T> Function(TutorJoinLinkRepository source) operation,
  ) async {
    final epoch = _epoch;
    _check(epoch);
    if (offline) {
      throw NetworkException('O link de convite exige conexão.', _problem);
    }
    final source = remote;
    if (source is! TutorJoinLinkRepository) {
      throw const FormatException('Link de convite indisponível.');
    }
    final result = await _authorized(
      () => operation(source as TutorJoinLinkRepository),
    );
    _check(epoch);
    return result;
  }

  @override
  Future<TutorJoinLink> getTutorJoinLink() =>
      _joinLink((source) => source.getTutorJoinLink());

  @override
  Future<void> setTutorJoinLink(TutorJoinLinkAction action) =>
      _joinLink((source) => source.setTutorJoinLink(action));

  @override
  Future<void> decideTutorReturn(String uid, {required bool approve}) =>
      _joinLink((source) => source.decideTutorReturn(uid, approve: approve));

  Future<List<T>> _readResource<T>(
    String resource,
    Future<List<T>> Function() read,
    T Function(Map<String, dynamic>) decode,
    Map<String, dynamic> Function(T) encode,
  ) async {
    final epoch = _epoch;
    _check(epoch);
    final uid = _uid!;
    final tenant = _tenant;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    try {
      final companies = await getCompanies();
      if (!companies.any((company) => company.id == tenant)) {
        await _deny(epoch);
        throw const FormatException('Vínculo removido.');
      }
      if (_offline) throw NetworkException(null, _problem);
      await remote.selectCompany(tenant);
      final items = await read();
      _check(epoch);
      if (tenant != _tenant) throw const FormatException('Empresa alterada.');
      final time = DateTime.now().toUtc();
      await _write(
        epoch,
        () => store.replaceResource(
          uid,
          tenant,
          resource,
          items.map(encode).toList(),
          time,
        ),
      );
      _check(epoch);
      _resourceTimes[resource] = time;
      _offline = false;
      _offlineResources.remove(resource);
      return items;
    } on NetworkException catch (error) {
      _check(epoch);
      _offlineProblem = error.problem;
      final cached = await _diskOperation(
        () => store.resource(uid, tenant, resource),
      );
      _check(epoch);
      if (tenant != _tenant) throw const FormatException('Empresa alterada.');
      if (cached == null) {
        throw NetworkException(
          'Esta consulta ainda não foi salva neste aparelho. Conecte-se e atualize.',
          _problem,
        );
      }
      _offline = true;
      _offlineResources.add(resource);
      _resourceTimes[resource] = cached.updatedAt;
      return cached.items.map(decode).toList();
    } on AppOutdatedException {
      // Only an update solves it; the access and the local copy stay.
      rethrow;
    } on FormatException {
      await _deny(epoch);
      rethrow;
    }
  }

  Future<T> _mutateResource<T>(
    String resource,
    Future<T> Function() operation,
    Map<String, dynamic> Function(T) encode,
  ) async {
    final epoch = _epoch;
    _check(epoch);
    final uid = _uid!;
    final tenant = _tenant;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    if (offline) {
      throw NetworkException(
        'Conecte-se e atualize os dados antes de alterar.',
        _problem,
      );
    }
    final confirmed = await _authorized(operation);
    _check(epoch);
    if (tenant != _tenant) throw const FormatException('Empresa alterada.');
    try {
      await _write(
        epoch,
        () => store.patchResourceItem(uid, tenant, resource, encode(confirmed)),
      );
    } catch (_) {
      _check(epoch);
      _localWarning =
          'Salvo no servidor. Atualize os dados para renovar a cópia offline.';
      try {
        await _diskOperation(
          () => store.invalidateResource(uid, tenant, resource),
        );
      } catch (_) {}
    }
    _check(epoch);
    return confirmed;
  }

  @override
  Future<Professional> saveProfessional(Professional value) => _mutateResource(
    'professionals',
    () => remote.saveProfessional(value),
    professionalToJson,
  );
  @override
  Future<ScheduleBlock> saveBlock(ScheduleBlock value) =>
      _mutateResource('blocks', () => remote.saveBlock(value), blockToJson);
  @override
  Future<Appointment> updateAppointmentNotes(String id, String notes) =>
      _mutateResource(
        'appointments',
        () => (remote as AppointmentNotesRepository).updateAppointmentNotes(
          id,
          notes,
        ),
        appointmentToJson,
      );
  @override
  Future<Appointment> saveAppointment(Appointment value) => _mutateResource(
    'appointments',
    () => remote.saveAppointment(value),
    appointmentToJson,
  );
  @override
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status,
  ) => _mutateResource(
    'appointments',
    () => remote.updateAppointmentStatus(id, status),
    appointmentToJson,
  );
  @override
  Future<Appointment> updatePetStatus(
    String id,
    String petId,
    AppointmentStatus status,
  ) => _mutateResource('appointments', () async {
    final target = remote;
    if (target is! PetExecutionRepository) {
      throw const FormatException('Atualize a integração da agenda.');
    }
    return (target as PetExecutionRepository).updatePetStatus(
      id,
      petId,
      status,
    );
  }, appointmentToJson);
  @override
  Future<void> removeBlock(String id) async {
    final epoch = _epoch;
    _check(epoch);
    final uid = _uid!;
    final tenant = _tenant;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    if (offline) throw NetworkException('Alterações exigem conexão.', _problem);
    await _authorized(() => remote.removeBlock(id));
    _check(epoch);
    if (tenant != _tenant) throw const FormatException('Empresa alterada.');
    try {
      await _write(
        epoch,
        () => store.removeResourceItem(uid, tenant, 'blocks', id),
      );
    } catch (_) {
      _check(epoch);
      _localWarning =
          'Bloqueio removido no servidor. Atualize a cópia offline.';
      try {
        await _diskOperation(
          () => store.invalidateResource(uid, tenant, 'blocks'),
        );
      } catch (_) {}
    }
  }

  SchedulingRepository get _schedule => remote as SchedulingRepository;
  @override
  Future<List<AvailableSlot>> getAvailableSlots(
    String customerId,
    List<AppointmentItem> items,
    DateTime day, {
    String? appointmentId,
  }) async {
    final epoch = _epoch;
    _check(epoch);
    if (offline) {
      throw NetworkException(
        'A disponibilidade exige consulta online.',
        _problem,
      );
    }
    final result = await _schedule.getAvailableSlots(
      customerId,
      items,
      day,
      appointmentId: appointmentId,
    );
    _check(epoch);
    return result;
  }

  @override
  Future<SchedulingPolicy> getSchedulingPolicy() async => (await _readResource(
    'policy',
    () async => [await _schedule.getSchedulingPolicy()],
    policyFromJson,
    policyToJson,
  )).single;
  @override
  Future<SchedulingPolicy> saveSchedulingPolicy(SchedulingPolicy value) async {
    final epoch = _epoch;
    _check(epoch);
    final uid = _uid!;
    final tenant = _tenant;
    if (tenant == null) throw const FormatException('Selecione uma empresa.');
    if (offline) throw NetworkException('Alterações exigem conexão.', _problem);
    final result = await _authorized(
      () => _schedule.saveSchedulingPolicy(value),
    );
    _check(epoch);
    try {
      await _write(
        epoch,
        () => store.replaceResource(uid, tenant, 'policy', [
          policyToJson(result),
        ], DateTime.now().toUtc()),
      );
    } catch (_) {
      _check(epoch);
      _localWarning = 'Horários salvos no servidor. Atualize a cópia offline.';
    }
    return result;
  }

  Future<T> _authorized<T>(Future<T> Function() operation) async {
    final epoch = _epoch;
    try {
      return await operation();
    } on SessionAccessException {
      // A denied mutation can mean a role restriction while reading is still
      // authorized. Revalidate canonically before discarding all readable data.
      try {
        final scopes = await remote.getCompanies();
        _check(epoch);
        if (!scopes.any((scope) => scope.id == _tenant)) {
          await _deny(epoch);
        } else {
          await _write(epoch, () => store.replaceAccess(_uid!, scopes));
          _companies = scopes;
        }
      } catch (_) {
        await _deny(epoch);
      }
      rethrow;
    }
  }

  @override
  Future<List<CompanyDriver>> getDrivers() async {
    final epoch = _epoch;
    _check(epoch);
    if (offline) {
      throw NetworkException(
        'Consulta de entregadores exige conexão.',
        _problem,
      );
    }
    final result = await _authorized(
      () => (remote as TransportManagementRepository).getDrivers(),
    );
    _check(epoch);
    return result;
  }

  @override
  Future<void> createTransport(TransportRequest request) async {
    final epoch = _epoch;
    _check(epoch);
    if (offline) throw NetworkException('Transporte exige conexão.', _problem);
    await _authorized(
      () => (remote as TransportManagementRepository).createTransport(request),
    );
    _check(epoch);
  }

  Future<T> _transportOnline<T>(
    Future<T> Function(TransportManagementRepository) action,
  ) async {
    final epoch = _epoch;
    _check(epoch);
    if (offline) {
      throw NetworkException('Gestão de transporte exige conexão.', _problem);
    }
    final result = await _authorized(
      () => action(remote as TransportManagementRepository),
    );
    _check(epoch);
    return result;
  }

  @override
  Future<List<ManagedTransport>> getTransports({String? appointmentId}) =>
      _transportOnline((r) => r.getTransports(appointmentId: appointmentId));
  @override
  Future<TransportConflictPreview> conflicts(
    String driverUid,
    DateTime at,
    int? duration, {
    String? excludeId,
    String? appointmentId,
  }) => _transportOnline(
    (r) => r.conflicts(
      driverUid,
      at,
      duration,
      excludeId: excludeId,
      appointmentId: appointmentId,
    ),
  );
  @override
  Future<void> reassign(
    ManagedTransport t,
    String driverUid,
    String reason,
    bool custodyConfirmed,
    String acknowledgement,
  ) => _transportOnline(
    (r) => r.reassign(t, driverUid, reason, custodyConfirmed, acknowledgement),
  );
  @override
  Future<void> manageIncident(
    String transportId,
    String incidentId,
    String status,
    String message,
  ) => _transportOnline(
    (r) => r.manageIncident(transportId, incidentId, status, message),
  );
  Future<T> _bookingOnline<T>(
    Future<T> Function(TransportBookingRepository) action,
  ) async {
    final epoch = _epoch, tenant = _tenant;
    _check(epoch);
    if (offline) {
      throw NetworkException('Pedidos de transporte exigem conexão.', _problem);
    }
    final result = await _authorized(
      () => action(remote as TransportBookingRepository),
    );
    _check(epoch);
    if (tenant != _tenant) throw const FormatException('Empresa alterada.');
    return result;
  }

  @override
  Future<Map<String, dynamic>> bookingPolicy() =>
      _bookingOnline((r) => r.bookingPolicy());
  @override
  Future<List<Map<String, dynamic>>> searchBookingAddress(String query) =>
      _bookingOnline((r) => r.searchBookingAddress(query));
  @override
  Future<void> saveBookingPolicy(Map<String, dynamic> policy) =>
      _bookingOnline((r) => r.saveBookingPolicy(policy));
  @override
  Future<List<Map<String, dynamic>>> bookingRequests() =>
      _bookingOnline((r) => r.bookingRequests());
  @override
  Future<void> decideBookingRequest(Map<String, dynamic> input) =>
      _bookingOnline((r) => r.decideBookingRequest(input));
}
