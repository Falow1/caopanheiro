import 'dart:async';

import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:equipe_app/domain/repositories/team_extras_repository.dart';

import '../domain/repositories/driver_session.dart';

import '../core/formatters.dart';
import '../core/location_sharing.dart';
import '../domain/models.dart';
import '../domain/repositories/transport_repository.dart';

class AppController extends AppControllerBase with LiveFollowing {
  /// [positions]: position of the phone; called as `positions:`.
  AppController(this._repository, {this.onSignOut, this._positions});
  final PositionSource? _positions;

  /// Live position while a transport of the driver is on the way; null
  /// without a phone position source or a server that receives it.
  late final DriverLocationSharing? location =
      _positions == null || _repository is! DriverLocationReporter
      ? null
      : DriverLocationSharing(
          _positions,
          (tenantId, fix) =>
              (_repository as DriverLocationReporter).reportLocation(
                tenantId,
                latitude: fix.latitude,
                longitude: fix.longitude,
                accuracy: fix.accuracy,
              ),
        );

  /// Starts or stops the position after each change of the trips.
  void _followRoute() {
    final tenants = _profile == null
        ? const <String>{}
        : _transports
              .where((item) => routeStatuses.contains(item.status))
              .map((item) => item.tenantId)
              .toSet();
    unawaited(location?.follow(tenants));
  }

  bool get hasPendingCommands =>
      _repository is AttachedSession &&
      (_repository as AttachedSession).hasPendingCommands;
  final void Function()? onSignOut;
  Future<void> _ending = Future.value();
  Future<void> get closingSession => _ending;
  final TransportRepository _repository;
  int _epoch = 0;
  DriverSession? get _session =>
      _repository is DriverSession ? _repository as DriverSession : null;
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
  Future<bool> enterCompany(String id) => _guard(() async {
    final epoch = _epoch;
    final session = _repository as AttachedSession;
    final profile = await session.attachCompany(id);
    if (epoch != _epoch) return;
    _profile = profile;
    await _reload();
    if (epoch == _epoch) selectTenant(id);
  });
  void detachView() {
    ++_epoch;
    _profile = null;
    _memberships = [];
    _transports = [];
    _activeTenantId = null;
    _followRoute();
    if (_repository is AttachedSession) {
      (_repository as AttachedSession).detachView();
    }
    clearOperationState(notify: false);
    notifyListeners();
  }

  Future<void> restoreSession() async {
    final session = _session;
    if (session == null) return;
    _profile = await session.restore();
    if (_profile != null) await refresh();
  }

  Future<bool> _guard(Future<void> Function() action) async {
    final epoch = _epoch;
    final success = await runGuarded(() async {
      try {
        await action();
      } on SessionAccessException {
        if (epoch == _epoch) signOut();
        rethrow;
      }
    });
    if (epoch != _epoch) {
      clearOperationState();
      return false;
    }
    return success;
  }

  Future<void> _reload() async {
    final epoch = _epoch;
    final transports = await _repository.getAssignedTransports();
    final memberships = await _repository.getMemberships();
    if (epoch != _epoch) return;
    _memberships = memberships;
    _transports = transports;
    _followRoute();
    if (!_memberships.any((item) => item.tenantId == _activeTenantId)) {
      _activeTenantId = null;
    }
    if (_memberships.length == 1) {
      _activeTenantId = _memberships.single.tenantId;
    }
  }

  Future<bool> refresh() => _guard(_reload);

  /// Back to the app: the same reading without loading state, so the screen
  /// keeps answering taps. A revoked access still ends the session.
  Future<bool> refreshQuietly() async {
    final epoch = _epoch;
    var revoked = false;
    final done = await runQuietly(() async {
      try {
        await _reload();
      } on SessionAccessException {
        revoked = true;
        rethrow;
      }
    });
    if (revoked && epoch == _epoch) signOut();
    return done;
  }

  /// Live refresh of the driver's trips: every petshop of the driver, since
  /// the list may show all of them.
  @override
  LiveSignalSource? get liveSource => _repository is LiveSignalsAware
      ? (_repository as LiveSignalsAware).liveSignals
      : null;
  @override
  Iterable<String> livePaths(String uid) => _profile == null
      ? const []
      : _memberships.map((item) => LiveSignalPaths.team(item.tenantId));
  @override
  Future<void> liveReload() => _reload();

  DriverProfile? _profile;
  List<TenantMembership> _memberships = const [];
  List<TransportJob> _transports = const [];
  String? _activeTenantId;

  DriverProfile? get profile => _profile;
  List<TenantMembership> get memberships => _memberships;
  List<TransportJob> get transports => _transports;
  String? get activeTenantId => _activeTenantId;

  TenantMembership? get activeTenant => _activeTenantId == null
      ? null
      : _memberships
            .where((item) => item.tenantId == _activeTenantId)
            .firstOrNull;
  List<TransportJob> get tenantTransports =>
      _transports.where((item) => item.tenantId == _activeTenantId).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  List<TransportJob> get todayTransports => tenantTransports
      .where(
        (item) =>
            (isSameDay(item.scheduledAt, DateTime.now()) ||
                item.scheduledAt.isBefore(DateTime.now())) &&
            !item.status.finished,
      )
      .toList();
  List<TransportJob> get futureTransports => tenantTransports
      .where(
        (item) =>
            !item.status.finished && item.scheduledAt.isAfter(DateTime.now()),
      )
      .toList();
  List<TransportJob> get history =>
      tenantTransports.where((item) => item.status.finished).toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  int todayCount(String tenantId) => _transports
      .where(
        (item) =>
            item.tenantId == tenantId &&
            (isSameDay(item.scheduledAt, DateTime.now()) ||
                item.scheduledAt.isBefore(DateTime.now())) &&
            !item.status.finished,
      )
      .length;

  Future<bool> signIn(String login, String password) => _guard(() async {
    final epoch = _epoch;
    final profile = await _repository.signIn(login, password);
    if (epoch != _epoch) return;
    _profile = profile;
    await _reload();
  });

  void selectTenant(String tenantId) {
    if (!_memberships.any((item) => item.tenantId == tenantId)) return;
    _activeTenantId = tenantId;
    notifyListeners();
  }

  TransportJob transportById(String id) =>
      _transports.firstWhere((item) => item.id == id);

  Future<bool> checkPets(
    String id,
    String phase,
    List<TransportPetCheck> checks,
  ) => _guard(() async {
    final epoch = _epoch;
    final updated = await _repository.checkPets(id, phase, checks);
    if (epoch == _epoch) _replace(updated);
  });
  Future<bool> transition(
    String id,
    TransportStatus expected,
    TransportStatus next,
  ) => _guard(() async {
    final epoch = _epoch;
    final updated = await _repository.transition(id, expected, next);
    if (epoch == _epoch) {
      _replace(updated);
      _followRoute();
    }
  });

  Future<bool> addIncident(String id, String type, String description) =>
      _guard(() async {
        final epoch = _epoch;
        final updated = await _repository.addIncident(id, type, description);
        if (epoch == _epoch) _replace(updated);
      });

  Future<void> retry() async {
    if (integrated) {
      await refresh();
    } else {
      clearOperationState();
    }
  }

  void signOut() {
    ++_epoch;
    final session = _session;
    if (session != null) _ending = session.signOut().catchError((Object _) {});
    _profile = null;
    _memberships = const [];
    _transports = const [];
    _activeTenantId = null;
    location?.reset();
    clearOperationState(notify: false);
    notifyListeners();
    onSignOut?.call();
  }

  void _replace(TransportJob updated) {
    _transports = _transports
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
  }
}
