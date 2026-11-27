import 'dart:async';

import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetPolicy;

import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppNotice, AppTipsStore;

import '../domain/models/appointment.dart';
import '../domain/models/pet.dart';
import '../domain/models/service.dart';
import '../domain/models/tutor.dart';
import '../domain/policies/tutor_invite.dart';
import '../domain/repositories/login_code_repository.dart';
import '../domain/repositories/petshop_repository.dart';
import '../domain/repositories/tutor_extras_repository.dart';
import '../domain/repositories/tutor_pet_policy.dart';
import '../domain/repositories/tutor_session.dart';
import '../domain/repositories/tutor_transport_repository.dart';

class AppController extends AppControllerBase
    with LiveFollowing
    implements AppTipsStore {
  AppController(this._repository);
  final PetshopRepository _repository;
  TutorSession? get _session =>
      _repository is TutorSession ? _repository as TutorSession : null;
  TutorExtrasRepository? get _extras => _repository is TutorExtrasRepository
      ? _repository as TutorExtrasRepository
      : null;
  bool get integrated => _session != null;

  /// Principal manager accounts are deleted only by the SaaS.
  bool get principalManager => _extras?.principalManager ?? false;

  ScreenTipsRepository? get _tips => _repository is ScreenTipsRepository
      ? _repository as ScreenTipsRepository
      : null;

  /// The account marks of the screen tips arrived from the server; without
  /// them (tests, demo data) no tip is shown and "Rever dicas" is hidden.
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

  /// Unread in-app notices of the selected petshop; refreshed with the data.
  int noticeCount = 0;
  bool get noticesAvailable => _extras != null && companyId != null;
  Future<List<AppNotice>> loadNotices() async {
    final extras = _extras;
    if (extras == null) return const [];
    final epoch = _epoch, company = companyId;
    final page = await extras.notices();
    if (epoch != _epoch || company != companyId) return const [];
    noticeCount = page.unread;
    notifyListeners();
    return page.items.map(AppNotice.fromJson).toList();
  }

  Future<void> markNoticesSeen() async {
    final extras = _extras;
    if (extras == null) return;
    final epoch = _epoch, company = companyId;
    await extras.markNoticesSeen();
    if (epoch != _epoch || company != companyId) return;
    noticeCount = 0;
    notifyListeners();
  }

  // A failed count never fails the refresh that asked for it.
  Future<void> _refreshNoticeCount() async {
    final extras = _extras;
    if (extras == null || companyId == null) {
      noticeCount = 0;
      return;
    }
    final epoch = _epoch, company = companyId;
    try {
      final page = await extras.notices();
      if (epoch != _epoch || company != companyId) return;
      noticeCount = page.unread;
      notifyListeners();
    } catch (_) {}
  }

  List<TutorCompany> get companies => _session?.companies ?? [];
  String? get companyId => _session?.selectedCompanyId;

  /// The selected petshop only shows pets and appointments (A1-u); the
  /// server refuses bookings and changes there.
  bool get companyReadOnly => _selectedCompany?.readOnly ?? false;
  String get companyContactPhone => _selectedCompany?.contactPhone ?? '';

  /// Name of the selected petshop, used in the messages about its pets.
  String get companyName => _selectedCompany?.name ?? 'Este petshop';

  /// Pets the selected petshop serves; without the rule, every pet.
  PetPolicy get petPolicy => _repository is TutorPetPolicySource
      ? (_repository as TutorPetPolicySource).petPolicy
      : const PetPolicy();

  /// New bookings and rescheduling go by phone for now (E2).
  bool get companyBookingPaused => _selectedCompany?.bookingPaused ?? false;

  /// Day from which the petshop may stop taking bookings in the app (E2).
  DateTime? get companyBookingNoticeFrom => _selectedCompany?.bookingNoticeFrom;
  TutorCompany? get _selectedCompany {
    final id = companyId;
    for (final company in companies) {
      if (company.id == id) return company;
    }
    return null;
  }

  bool get emailVerified => _session?.emailVerified ?? true;

  @override
  Object? get networkProblemSource => _repository;
  Tutor? _tutor;
  List<Pet> _pets = const [];
  List<PetService> _services = const [];
  List<Appointment> _appointments = const [];
  Appointment? _lastConfirmedAppointment;
  int _epoch = 0;
  Tutor? get tutor => _tutor;
  List<Pet> get pets => _pets;
  List<PetService> get services => _services;
  List<Appointment> get appointments => _appointments;
  Appointment? get lastConfirmedAppointment => _lastConfirmedAppointment;
  Future<bool> _guard(Future<void> Function() action) async {
    final epoch = _epoch;
    final success = await runGuarded(() async {
      try {
        await action();
      } on SessionAccessException {
        await _handleAccessLoss(epoch);
        rethrow;
      } on NetworkException {
        if (epoch == _epoch && integrated) {
          _pets = [];
          _services = [];
          _appointments = [];
        }
        rethrow;
      }
    });
    if (epoch != _epoch) {
      clearOperationState();
      return false;
    }
    return success;
  }

  /// A refused operation may mean only that this petshop removed the link.
  /// The context is checked again: a valid account stays signed in (and sees
  /// the removal notice); an invalid identity ends the session.
  Future<void> _handleAccessLoss(int epoch) async {
    if (epoch != _epoch) return;
    final session = _session;
    if (_tutor == null) {
      // Refused before anyone entered (wrong password, disabled account):
      // only the partial sign-in ends, and the reason stays on the login.
      if (session != null) {
        unawaited(session.signOut().catchError((Object _) {}));
      }
      return;
    }
    if (session == null) {
      signOut();
      return;
    }
    try {
      final tutor = await session.refreshContext();
      if (epoch != _epoch) return;
      _tutor = tutor;
      _takeRemovedCompany();
      await _loadData();
      notifyListeners();
    } on SessionAccessException {
      if (epoch == _epoch) signOut();
    } catch (_) {
      // Network or transient failure: keep the session; the next refresh decides.
    }
  }

  Future<bool> deleteOwnAccount(String password) async {
    final epoch = _epoch;
    final success = await _guard(() async {
      if (_repository is! AccountDeletionRepository) {
        throw const FormatException('Atualize a integração da conta.');
      }
      await (_repository as AccountDeletionRepository).deleteOwnAccount(
        password,
      );
    });
    if (!success || epoch != _epoch) return false;
    signOut(forgetInvite: true);
    return true;
  }

  /// Invite code opened through a link; kept only in memory until accepted.
  String? pendingInvite;

  /// Explains a petshop link removed by the company since the last refresh.
  String? linkNotice;

  /// The petshop's fixed link registered a return request: this petshop
  /// unlinked the account before and its principal manager decides. It
  /// stops being pending when that petshop is among the companies again.
  String? _returnCompanyId;
  bool get returnRequested =>
      _returnCompanyId != null &&
      !companies.any((company) => company.id == _returnCompanyId);

  void clearReturnRequested() {
    _returnCompanyId = null;
    notifyListeners();
  }

  /// The account lacks the name or phone, as one created by Google; the
  /// shell asks for them once after entering, before any link.
  bool get accountContactMissing => !(_session?.accountContactComplete ?? true);

  Future<bool> saveAccountContact(String name, String phone) =>
      _guard(() async {
        final session = _session;
        if (session == null) return;
        final epoch = _epoch;
        final tutor = await session.saveAccountContact(name, phone);
        if (epoch == _epoch) _tutor = tutor;
      });

  /// Drops the last operation message, used when a page that showed its own
  /// result returns to the login.
  void clearError() => clearOperationState();

  void clearLinkNotice() {
    linkNotice = null;
    notifyListeners();
  }

  void _takeRemovedCompany() {
    // An approved return ends the request, so a later unlink is not shown
    // as a request still waiting.
    if (_returnCompanyId != null && !returnRequested) _returnCompanyId = null;
    final name = _session?.takeRemovedCompany();
    final paused = _extras?.pausedCompanies ?? const <String>[];
    if (name != null) {
      // A paused company keeps the link: saying it was removed would be false.
      linkNotice = paused.contains(name)
          ? '$name está temporariamente indisponível no aplicativo. Seu vínculo, seus pets e seus agendamentos continuam guardados. Tente mais tarde ou fale com o petshop.'
          : 'Seu acesso a $name foi encerrado pela empresa. Sua conta e os outros vínculos continuam ativos.';
    } else if (linkNotice == null && companies.isEmpty && paused.isNotEmpty) {
      linkNotice =
          '${paused.join(', ')} está temporariamente indisponível no aplicativo. Seu vínculo continua guardado. Tente mais tarde ou fale com o petshop.';
    }
  }

  Future<void> restoreSession() async {
    final session = _session;
    if (session == null) return;
    _tutor = await session.restore();
    if (_tutor != null) await refresh();
  }

  /// Always reports success to the screen; the answer must not reveal
  /// whether the e-mail has an account.
  Future<bool> requestPasswordReset(String email) => _guard(() async {
    try {
      await _session?.sendPasswordReset(email);
    } on SessionAccessException {
      // A refused account (disabled, for example) answers like any other
      // e-mail, so the screen reveals nothing about it.
    }
  });

  /// Second step of a new login (a code by e-mail), skippable in this
  /// demonstration because the server does not require it. A restored
  /// session does not ask again.
  bool _loginCodePending = false;
  String? _loginChallenge;
  bool get loginCodePending =>
      _loginCodePending && _tutor != null && _repository is LoginCodeRepository;
  Future<bool> requestLoginCode() => _guard(() async {
    _loginChallenge = await (_repository as LoginCodeRepository)
        .requestLoginCode();
  });
  Future<bool> verifyLoginCode(String code) => _guard(() async {
    final challenge = _loginChallenge;
    if (challenge == null) {
      throw const FormatException(
        'Toque em Enviar código para receber um código.',
      );
    }
    await (_repository as LoginCodeRepository).verifyLoginCode(challenge, code);
    _loginChallenge = null;
    _loginCodePending = false;
  });
  void skipLoginCode() {
    _loginCodePending = false;
    clearOperationState();
    notifyListeners();
  }

  Future<bool> signIn(String identifier, String password) => _guard(() async {
    final epoch = _epoch;
    final tutor = await _repository.signIn(identifier, password);
    if (epoch != _epoch) return;
    _tutor = tutor;
    _loginCodePending = true;
    _takeRemovedCompany();
    await _loadData();
  });
  Future<bool> signInWithGoogle() => _guard(() async {
    final session = _session;
    if (session == null) return;
    final epoch = _epoch;
    final tutor = await session.signInWithGoogle();
    if (epoch != _epoch) return;
    _tutor = tutor;
    _loginCodePending = true;
    _takeRemovedCompany();
    await _loadData();
  });
  List<String> get providers => _session?.providers ?? const [];
  Future<bool> linkGoogle() => _guard(() async {
    await _session?.linkGoogle();
    notifyListeners();
  });
  Future<bool> signUp(Tutor newTutor, String password) => _guard(() async {
    final epoch = _epoch;
    final tutor = await _repository.signUp(newTutor, password);
    if (epoch != _epoch) return;
    _tutor = tutor;
    await _loadData();
  });
  Future<bool> selectCompany(String id) => _guard(() async {
    final session = _session;
    if (session == null) return;
    final epoch = _epoch;
    _pets = [];
    _services = [];
    _appointments = [];
    _lastConfirmedAppointment = null;
    try {
      final tutor = await session.selectCompany(id);
      if (epoch != _epoch) return;
      _tutor = tutor;
      // The chosen petshop may have removed the link meanwhile; the refresh
      // then opens the remaining one and the notice must explain it now.
      _takeRemovedCompany();
      await _loadData();
    } on SessionAccessException {
      if (epoch == _epoch) signOut();
      rethrow;
    }
  });
  Future<bool> refresh() => _guard(_refreshData);

  Future<void> _refreshData() async {
    final epoch = _epoch;
    final session = _session;
    if (session != null) {
      final tutor = await session.refreshContext();
      if (epoch != _epoch) return;
      _tutor = tutor;
      _takeRemovedCompany();
    }
    await _loadData();
  }

  /// Live refresh: the server moved the signal of this tutor or of the
  /// selected petshop's catalog. The same queries run without loading state
  /// or error messages; a failure waits for the next signal or a manual
  /// refresh.
  @override
  LiveSignalSource? get liveSource => _repository is LiveSignalsAware
      ? (_repository as LiveSignalsAware).liveSignals
      : null;
  @override
  Iterable<String> livePaths(String uid) {
    final company = companyId;
    if (_tutor == null || company == null) return const [];
    return [
      LiveSignalPaths.catalog(company),
      LiveSignalPaths.tutor(company, uid),
    ];
  }

  @override
  Future<void> liveReload() => _refreshData();
  Future<bool> acceptLink(String input) async {
    final code = tutorInviteCode(input);
    final epoch = _epoch;
    var refused = false;
    _returnCompanyId = null;
    final accepted = await _guard(() async {
      final session = _session;
      if (session == null) return;
      if (code == null) {
        throw const FormatException('Informe o link ou o código do convite.');
      }
      final TutorLinkResult result;
      try {
        result = await session.acceptLink(code);
      } on SessionAccessException {
        refused = true;
        rethrow;
      }
      if (epoch != _epoch) return;
      if (pendingInvite == code) pendingInvite = null;
      // The request is registered once; opening the link again only repeats it.
      // Only the fixed link (`tenantId.token`) answers with a request.
      _returnCompanyId = result == TutorLinkResult.pending
          ? code.split('.').first
          : null;
      _tutor = await session.refreshContext();
      _takeRemovedCompany();
      await _loadData();
    });
    // Refused while the account stays signed in: this invite does not serve
    // this account (used, expired or removed), so it is no longer offered.
    if (refused &&
        epoch == _epoch &&
        _tutor != null &&
        code != null &&
        pendingInvite == code) {
      pendingInvite = null;
      notifyListeners();
    }
    return accepted;
  }

  Future<bool> sendVerification() => _guard(() async {
    await _session?.sendVerification();
  });

  /// Slots for moving [appointmentId]; its own reservation does not block.
  Future<List<TutorSlot>> rescheduleSlots(
    String day,
    List<Map<String, dynamic>> items,
    String appointmentId,
  ) async {
    final extras = _extras;
    if (extras == null) return [];
    final epoch = _epoch;
    try {
      return await extras.rescheduleSlots(day, items, appointmentId);
    } on SessionAccessException {
      await _handleAccessLoss(epoch);
      rethrow;
    }
  }

  /// Transport asked for an appointment that already exists.
  Future<bool> requestTransport(String appointmentId, String quoteId) => _guard(
    () async {
      final extras = _extras;
      if (extras == null) {
        throw const FormatException(
          'Atualize o aplicativo para pedir transporte.',
        );
      }
      final epoch = _epoch;
      await extras.requestTransport(appointmentId, quoteId);
      if (epoch != _epoch) return;
      // Confirmed request; a failed reload must not look like a failed request.
      try {
        final rows = await _repository.getAppointments();
        if (epoch == _epoch) _appointments = rows;
      } on NetworkException {
        // The next refresh brings the updated appointment.
      }
    },
  );
  Future<List<TutorSlot>> availableSlots(
    String day,
    List<Map<String, dynamic>> items,
  ) async {
    final session = _session;
    if (session == null) return [];
    final epoch = _epoch;
    try {
      return await session.availableSlots(day, items);
    } on SessionAccessException {
      await _handleAccessLoss(epoch);
      rethrow;
    }
  }

  TutorTransportRepository get _transport =>
      _repository as TutorTransportRepository;
  Future<T> _transportRead<T>(
    Future<T> Function(TutorTransportRepository) action,
  ) async {
    final epoch = _epoch, company = companyId;
    try {
      final result = await action(_transport);
      if (epoch != _epoch || company != companyId) {
        throw const SessionChangedException('Sessão ou empresa alterada.');
      }
      return result;
    } on SessionAccessException {
      await _handleAccessLoss(epoch);
      rethrow;
    }
  }

  /// Whether the selected petshop offers transport in the booking, as its
  /// policy said in this session; null while not read. With it the booking
  /// shows five steps.
  bool? get transportOffered {
    final offer = _transportOffer;
    return offer != null && offer.$1 == _epoch && offer.$2 == companyId
        ? offer.$3
        : null;
  }

  (int, String?, bool)? _transportOffer;

  Future<Map<String, dynamic>> transportPolicy() async {
    final epoch = _epoch, company = companyId;
    final policy = await _transportRead((r) => r.transportPolicy());
    final offered = policy['enabled'] == true;
    if (epoch == _epoch &&
        company == companyId &&
        transportOffered != offered) {
      _transportOffer = (epoch, company, offered);
      notifyListeners();
    }
    return policy;
  }

  /// Reads the policy once per petshop, for the steps of the booking. A
  /// failure leaves it unknown, and the transport step reads it again.
  Future<void> loadTransportOffer() async {
    if (!integrated ||
        _repository is! TutorTransportRepository ||
        transportOffered != null) {
      return;
    }
    try {
      await transportPolicy();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> searchTransportAddress(String query) =>
      _transportRead((r) => r.searchTransportAddress(query));
  Future<Map<String, dynamic>> quoteTransport(
    bool pickup,
    bool returnTrip,
    Map<String, dynamic> location,
  ) => _transportRead((r) => r.quoteTransport(pickup, returnTrip, location));
  Future<Map<String, dynamic>> trackTransport(String appointmentId) =>
      _transportRead((r) => r.trackTransport(appointmentId));
  Future<bool> saveTutor(Tutor tutor) => _guard(() async {
    final epoch = _epoch;
    final updated = await _repository.updateTutor(tutor);
    if (epoch == _epoch) _tutor = updated;
  });
  Future<bool> savePet(Pet pet) => _guard(() async {
    final epoch = _epoch;
    await _repository.savePet(pet);
    if (epoch != _epoch) return;
    // Confirmed mutation; do not turn a second read failure into a failed save.
    if (integrated) {
      final old = _pets.where((item) => item.id == pet.id).firstOrNull;
      _pets = [
        ..._pets.where((item) => item.id != pet.id),
        pet.keepingServiceOf(old),
      ];
    } else {
      final pets = await _repository.getPets();
      if (epoch == _epoch) _pets = pets;
    }
  });
  Map<String, dynamic>? serviceQuoteChange;
  Future<bool> createAppointment(Appointment appointment) => _guard(() async {
    final epoch = _epoch;
    serviceQuoteChange = null;
    late Appointment confirmed;
    try {
      confirmed = await _repository.createAppointment(appointment);
    } on ServiceQuoteChangedException catch (changed) {
      if (epoch == _epoch) serviceQuoteChange = changed.quote;
      rethrow;
    }
    if (epoch != _epoch) return;
    _lastConfirmedAppointment = confirmed;
    if (integrated) {
      _appointments = [
        ..._appointments.where((old) => old.id != confirmed.id),
        confirmed,
      ];
    } else {
      final rows = await _repository.getAppointments();
      if (epoch == _epoch) _appointments = rows;
    }
  });
  Future<bool> cancelAppointment(String id) => _guard(() async {
    final epoch = _epoch;
    final confirmed = await _repository.cancelAppointment(id);
    if (epoch != _epoch) return;
    if (integrated) {
      _appointments = _appointments
          .map((old) => old.id == confirmed.id ? confirmed : old)
          .toList();
    } else {
      final rows = await _repository.getAppointments();
      if (epoch == _epoch) _appointments = rows;
    }
  });

  /// [forgetInvite] is used by the confirmed Sair: the next person to sign in
  /// on this page must not inherit an invite opened by someone else. Automatic
  /// endings (wrong password, expired identity) keep it for the next attempt.
  void signOut({bool forgetInvite = false}) {
    if (forgetInvite) pendingInvite = null;
    _loginCodePending = false;
    _loginChallenge = null;
    serviceQuoteChange = null;
    linkNotice = null;
    _returnCompanyId = null;
    noticeCount = 0;
    ++_epoch;
    _tutor = null;
    _pets = [];
    _services = [];
    _appointments = [];
    _lastConfirmedAppointment = null;
    clearOperationState(notify: false);
    notifyListeners();
    final session = _session;
    if (session != null) unawaited(session.signOut().catchError((Object _) {}));
  }

  Future<void> _loadData() async {
    if (integrated && companyId == null) {
      _pets = [];
      _services = [];
      _appointments = [];
      noticeCount = 0;
      return;
    }
    final epoch = _epoch;
    final rows = await Future.wait([
      _repository.getPets(),
      _repository.getServices(),
      _repository.getAppointments(),
    ]);
    if (epoch != _epoch) return;
    _pets = rows[0] as List<Pet>;
    _services = rows[1] as List<PetService>;
    _appointments = rows[2] as List<Appointment>;
    unawaited(_refreshNoticeCount());
  }
}
