import 'dart:async';

import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:equipe_app/domain/repositories/team_extras_repository.dart';

import '../domain/models.dart';
import '../domain/repositories/professional_repository.dart';
import '../domain/repositories/professional_session.dart';

class AppController extends AppControllerBase with LiveFollowing {
  AppController(this._repository, {this.onSignOut});
  bool get hasPendingCommands =>
      _repository is AttachedSession &&
      (_repository as AttachedSession).hasPendingCommands;
  final void Function()? onSignOut;
  Future<void> _ending = Future.value();
  Future<void> get closingSession => _ending;
  final ProfessionalRepository _repository;
  Professional? _professional;
  List<Appointment> _appointments = const [];
  int _epoch = 0;
  ProfessionalSession? get _session => _repository is ProfessionalSession
      ? _repository as ProfessionalSession
      : null;
  bool get integrated => _session != null;

  /// In-app notices of this area; null without server or while read-only.
  RoleNoticesSource? get noticesSource {
    final Object repository = _repository;
    return repository is RoleNoticesSource && !readOnly ? repository : null;
  }

  bool get readOnly => _session?.readOnly ?? false;

  @override
  Object? get networkProblemSource => _repository;
  DateTime? get updatedAt => _session?.updatedAt;
  String? get cacheWarning => _session?.cacheWarning;
  List<ProfessionalCompany> get companies => _session?.companies ?? [];
  String? get companyId => _session?.selectedCompanyId;
  Professional? get professional => _professional;
  List<Appointment> get appointments => _appointments;
  Future<bool> _guard(Future<void> Function() action) async {
    final epoch = _epoch;
    final success = await runGuarded(action);
    if (epoch != _epoch) {
      clearOperationState();
      return false;
    }
    return success;
  }

  Future<bool> enterCompany(String id) => _guard(() async {
    final epoch = _epoch;
    final session = _repository as AttachedSession;
    final profile = await session.attachCompany(id);
    if (epoch != _epoch) return;
    _professional = profile;
    try {
      final rows = await _repository.getAppointments(profile.id);
      if (epoch == _epoch) _appointments = rows;
    } on SessionAccessException {
      if (epoch == _epoch) signOut();
      rethrow;
    }
  });
  void detachView() {
    ++_epoch;
    _professional = null;
    _appointments = [];
    if (_repository is AttachedSession) {
      (_repository as AttachedSession).detachView();
    }
    clearOperationState(notify: false);
    notifyListeners();
  }

  Future<void> restoreSession() async {
    final session = _session;
    if (session == null) return;
    final epoch = _epoch;
    final profile = await session.restore();
    if (epoch != _epoch) return;
    _professional = profile;
    if (profile != null && session.selectedCompanyId != null) await refresh();
  }

  Future<bool> signIn(String identifier, String password) => _guard(() async {
    final epoch = _epoch;
    final profile = await _repository.signIn(identifier, password);
    if (epoch != _epoch) return;
    if (_session == null || companyId != null) {
      final appointments = await _repository.getAppointments(profile.id);
      if (epoch != _epoch) return;
      _appointments = appointments;
    }
    _professional = profile;
  });
  Future<bool> selectCompany(String id) => _guard(() async {
    final session = _session;
    if (session == null) return;
    final epoch = _epoch;
    _appointments = [];
    try {
      final profile = await session.selectCompany(id);
      final appointments = await _repository.getAppointments(profile.id);
      if (epoch != _epoch) return;
      _professional = profile;
      _appointments = appointments;
    } on SessionAccessException {
      if (epoch == _epoch) signOut();
      rethrow;
    }
  });

  /// Live refresh of the professional's agenda in the open petshop.
  @override
  LiveSignalSource? get liveSource => _repository is LiveSignalsAware
      ? (_repository as LiveSignalsAware).liveSignals
      : null;
  @override
  Iterable<String> livePaths(String uid) {
    final company = companyId;
    if (_professional == null || company == null) return const [];
    return [LiveSignalPaths.team(company)];
  }

  @override
  Future<void> liveReload() async {
    final profile = _professional;
    if (profile == null || integrated && companyId == null) return;
    final epoch = _epoch;
    final rows = await _repository.getAppointments(profile.id);
    if (epoch == _epoch) _appointments = rows;
  }

  /// Back to the app: the same reading without loading state, so the screen
  /// keeps answering taps. A revoked access still ends the session.
  Future<bool> refreshQuietly() async {
    final epoch = _epoch;
    var revoked = false;
    final done = await runQuietly(() async {
      try {
        await liveReload();
      } on SessionAccessException {
        revoked = true;
        rethrow;
      }
    });
    if (revoked && epoch == _epoch) signOut();
    return done;
  }

  Future<bool> refresh() => _guard(() async {
    final profile = _professional;
    if (profile == null || integrated && companyId == null) return;
    final epoch = _epoch;
    try {
      final rows = await _repository.getAppointments(profile.id);
      if (epoch == _epoch) _appointments = rows;
    } on SessionAccessException {
      if (epoch == _epoch) signOut();
      rethrow;
    }
  });
  Future<bool> _change(Future<void> Function() action) => _guard(() async {
    final epoch = _epoch;
    try {
      await action();
      if (epoch != _epoch) return;
      final session = _session;
      if (session != null) {
        _appointments = session.confirmedAppointments;
        return;
      }
      final rows = await _repository.getAppointments(_professional!.id);
      if (epoch == _epoch) _appointments = rows;
    } on SessionAccessException {
      if (epoch == _epoch) signOut();
      rethrow;
    }
  });
  Future<bool> updateStatus(String id, AppointmentStatus status) =>
      _change(() => _repository.updateStatus(id, status));
  Future<bool> addObservation(String id, String text) => _change(
    () => _repository.addObservation(
      id,
      ServiceObservation(text: text.trim(), createdAt: DateTime.now()),
    ),
  );
  void signOut() {
    ++_epoch;
    _professional = null;
    _appointments = [];
    clearOperationState(notify: false);
    notifyListeners();
    final session = _session;
    if (session != null) _ending = session.signOut().catchError((Object _) {});
    onSignOut?.call();
  }
}
