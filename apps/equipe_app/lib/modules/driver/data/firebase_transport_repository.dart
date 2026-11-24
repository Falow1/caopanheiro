import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show AppointmentStatus;
import 'package:caopanheiro_core/caopanheiro_core.dart';

import '../domain/models.dart';
import '../domain/repositories/transport_repository.dart';
import '../domain/repositories/driver_session.dart';
import 'package:equipe_app/domain/repositories/team_extras_repository.dart';

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);
DateTime _date(dynamic value) => DateTime.parse(value as String).toLocal();

class FirebaseTransportRepository
    implements
        TransportRepository,
        DriverSession,
        AttachedSession,
        RoleNoticesSource,
        LiveSignalsAware,
        NetworkProblemSource {
  FirebaseTransportRepository(this._gateway, this._cache);
  @override
  LiveSignalSource? get liveSignals => _gateway.liveSignals;
  @override
  Future<Map<String, dynamic>> roleNotices(String tenantId) =>
      _gateway.call('getNotices', {'tenantId': tenantId, 'role': 'DRIVER'});
  @override
  Future<void> markRoleNoticesSeen(String tenantId) async {
    await _gateway.call('markNoticesSeen', {
      'tenantId': tenantId,
      'role': 'DRIVER',
    });
  }

  @override
  bool get hasPendingCommands => _commands.hasPending;
  String? _unifiedTenant;
  final LocalFirebaseGateway _gateway;
  final SqlSnapshotCache _cache;

  /// Reason of the latest call without answer, for the read-only banner.
  @override
  NetworkProblem? get lastNetworkProblem => _gateway.lastNetworkProblem;
  final ExplicitCommands _commands = ExplicitCommands();
  List<Map<String, dynamic>> _scopes = [];
  List<Map<String, dynamic>> _rows = [];
  int _epoch = 0;
  Future<void> _ending = Future.value();
  final Set<String> _offlineCompanies = {};
  final Map<String, DateTime> _times = {};
  @override
  bool get readOnly => _offlineCompanies.isNotEmpty;
  @override
  DateTime? get updatedAt =>
      _times.isEmpty ? null : (_times.values.toList()..sort()).first;
  @override
  String? cacheWarning;
  void _check(int epoch, String? uid) {
    if (epoch != _epoch || uid == null || uid != _gateway.uid) {
      throw const SessionChangedException('Sessão encerrada.');
    }
  }

  DriverProfile _profile() {
    final value = _map(_scopes.first['profile']);
    return DriverProfile(
      id: _gateway.uid!,
      name: value['name'] as String,
      email: value['email'] as String,
      phone: value['phone'] as String,
    );
  }

  Future<void> _context() async {
    final epoch = _epoch;
    final uid = _gateway.uid;
    final value = await _gateway.call('getApplicationContext', {
      'role': 'DRIVER',
    });
    _check(epoch, uid);
    if (value['uid'] != uid) {
      throw const SessionAccessException('Identidade divergente.');
    }
    final scopes = (value['companies'] as List).map(_map).toList();
    if (scopes.isEmpty) {
      throw const SessionAccessException('Sem empresa autorizada.');
    }
    await _cache.bind(uid!, scopes);
    _check(epoch, uid);
    _scopes = _unifiedTenant == null
        ? scopes
        : scopes.where((s) => s['id'] == _unifiedTenant).toList();
    if (_scopes.isEmpty) {
      throw const SessionAccessException('Função removida neste petshop.');
    }
    _rows.removeWhere(
      (row) => !scopes.any((scope) => scope['id'] == row['tenantId']),
    );
    _offlineCompanies.removeWhere(
      (id) => !scopes.any((scope) => scope['id'] == id),
    );
    _times.removeWhere((id, time) => !scopes.any((scope) => scope['id'] == id));
  }

  @override
  Future<DriverProfile> attachCompany(String id) async {
    await _ending;
    detachView();
    _unifiedTenant = id;
    final uid = _gateway.uid;
    if (uid == null) throw const SessionAccessException('Entre novamente.');
    try {
      await _context();
    } on NetworkException {
      _scopes = (await _cache.scopes(uid)).where((s) => s['id'] == id).toList();
      if (_scopes.isEmpty) rethrow;
      _offlineCompanies.add(id);
    }
    if (!_scopes.any((s) => s['id'] == id)) {
      throw const SessionAccessException('Função removida neste petshop.');
    }
    return _profile();
  }

  @override
  void detachView() {
    ++_epoch;
    _commands.clear();
    _rows = [];
    _scopes = [];
    _unifiedTenant = null;
    _offlineCompanies.clear();
    _times.clear();
    cacheWarning = null;
  }

  @override
  Future<DriverProfile> signIn(String identifier, String password) async {
    await _ending;
    await signOut();
    try {
      await _gateway.signIn(identifier, password);
      await _context();
      return _profile();
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<DriverProfile?> restore() async {
    final uid = _gateway.uid;
    if (uid == null || await _cache.owner != uid) {
      await _cache.clear();
      return null;
    }
    try {
      await _context();
    } on NetworkException {
      _scopes = await _cache.scopes(uid);
      _offlineCompanies.addAll(_scopes.map((scope) => scope['id'] as String));
    } on SessionAccessException {
      await signOut();
      return null;
    }
    return _scopes.isEmpty ? null : _profile();
  }

  @override
  Future<List<TenantMembership>> getMemberships() async => _scopes
      .map(
        (v) => TenantMembership(
          tenantId: v['id'] as String,
          tenantName: v['name'] as String,
        ),
      )
      .toList();
  @override
  Future<List<TransportJob>> getAssignedTransports() async {
    final epoch = _epoch;
    final uid = _gateway.uid;
    try {
      bool contextOnline = true;
      try {
        await _context();
      } on NetworkException {
        contextOnline = false;
      }
      _check(epoch, uid);
      final rows = <Map<String, dynamic>>[];
      for (final scope in _scopes) {
        final tenant = scope['id'] as String;
        try {
          if (!contextOnline) throw const NetworkException();
          final pageRows = <Map<String, dynamic>>[];
          String? cursor;
          do {
            final page = await _gateway.call('getProfileData', {
              'tenantId': tenant,
              'role': 'DRIVER',
              'resource': 'transports',
              'cursor': cursor,
            });
            _check(epoch, uid);
            pageRows.addAll((page['items'] as List).map(_map));
            cursor = page['nextCursor'] as String?;
          } while (cursor != null);
          // Parse before replacing a complete, previously authorized SQL snapshot.
          pageRows.map(_job).toList();
          final now = DateTime.now();
          await _cache.write(
            uid!,
            tenant,
            'transports',
            pageRows,
            updatedAt: now,
          );
          _check(epoch, uid);
          _times[tenant] = now;
          _offlineCompanies.remove(tenant);
          rows.addAll(pageRows);
        } on NetworkException {
          _check(epoch, uid);
          final saved = await _cache.read(uid!, tenant, 'transports');
          _check(epoch, uid);
          if (saved == null) rethrow;
          _times[tenant] = saved.updatedAt;
          _offlineCompanies.add(tenant);
          rows.addAll(saved.items);
        }
      }
      _check(epoch, uid);
      _rows = rows;
      if (!readOnly) _commands.clear();
      return rows.map(_job).toList();
    } on SessionAccessException {
      await signOut();
      rethrow;
    }
  }

  TransportAddress _address(dynamic input) {
    final v = _map(input);
    final coordinates = v['point'] is Map ? _map(v['point']) : null;
    return TransportAddress(
      name: v['name'] as String,
      street: v['street'] as String,
      district: v['district'] as String,
      phone: v['phone'] as String,
      latitude: (coordinates?['lat'] as num?)?.toDouble(),
      longitude: (coordinates?['lng'] as num?)?.toDouble(),
    );
  }

  List<TransportPetCheck> _checks(dynamic items) => (items as List).map((raw) {
    final item = _map(raw);
    return TransportPetCheck(
      item['petId'] as String,
      item['confirmed'] as bool,
      item['reason'] as String? ?? '',
    );
  }).toList();
  TransportJob _job(Map<String, dynamic> v) => TransportJob(
    id: '${(v['tenantId'] as String).length}:${v['tenantId']}${v['id']}',
    recordNumber: readRecordNumber(v['recordNumber']),
    appointmentNumber: readRecordNumber(v['appointmentNumber']),
    tenantId: v['tenantId'] as String,
    appointmentId: v['appointmentId'] as String,
    type: TransportType.values.firstWhere((type) => type.apiValue == v['type']),
    scheduledAt: _date(v['scheduledAt']),
    companyScheduledAt: v['localScheduledAt'] == null
        ? null
        : DateTime.parse(v['localScheduledAt'] as String),
    status: TransportStatus.fromApi(v['status'] as String),
    origin: _address(v['origin']),
    destination: _address(v['destination']),
    pets: (v['pets'] as List).map((item) {
      final p = _map(item);
      return TransportPet(
        id: p['id'] as String? ?? '',
        recordNumber: readRecordNumber(p['recordNumber']),
        name: p['name'] as String,
        species: p['species'] as String? ?? '',
        serviceStatus: p['serviceStatus'] == null
            ? null
            : AppointmentStatus.fromApi(p['serviceStatus'] as String),
        breed: p['breed'] as String,
        size: p['size'] as String,
      );
    }).toList(),
    notes: v['notes'] as String? ?? '',
    collectionChecks: v['collectionChecks'] == null
        ? null
        : _checks(_map(v['collectionChecks'])['items']),
    deliveryChecks: v['deliveryChecks'] == null
        ? const []
        : _checks(_map(v['deliveryChecks'])['items']),
    assignmentHistory: ((v['assignmentHistory'] as List?) ?? []).map((raw) {
      final a = _map(raw);
      return '${a['at']} · ${a['actorName']}: ${a['fromUid']} → ${a['toUid']}\n${a['reason']}${a['custodyConfirmed'] == true ? ' · Transferência física confirmada' : ''}';
    }).toList(),
    events: (v['events'] as List).map((item) {
      final e = _map(item);
      return TransportEvent(
        status: TransportStatus.fromApi(e['status'] as String),
        createdAt: _date(e['createdAt']),
        actor: e['actor'] as String,
      );
    }).toList(),
    incidents: ((v['incidents'] as List?) ?? []).map((item) {
      final i = _map(item);
      return TransportIncident(
        id: i['id'] as String? ?? '',
        status: i['status'] as String? ?? 'OPEN',
        response: i['response'] as String? ?? '',
        resolution: i['resolution'] as String? ?? '',
        type: i['type'] as String,
        description: i['description'] as String,
        createdAt: _date(i['createdAt']),
        driverName: i['driverName'] as String,
      );
    }).toList(),
    startedAt: v['startedAt'] == null ? null : _date(v['startedAt']),
    collectedAt: v['collectedAt'] == null ? null : _date(v['collectedAt']),
    deliveredAt: v['deliveredAt'] == null ? null : _date(v['deliveredAt']),
  );
  Future<TransportJob> _mutate(
    String id,
    String command,
    Map<String, dynamic> input,
  ) async {
    if (readOnly) {
      throw const FormatException(
        'Conecte-se e atualize para registrar o transporte.',
      );
    }
    final row = _rows
        .where(
          (row) =>
              '${(row['tenantId'] as String).length}:${row['tenantId']}${row['id']}' ==
              id,
        )
        .firstOrNull;
    if (row == null) {
      throw const FormatException(
        'Atualize os transportes antes de continuar.',
      );
    }
    final epoch = _epoch;
    final uid = _gateway.uid;
    final tenant = row['tenantId'] as String;
    try {
      final result = await _commands.run(command, {
        'tenantId': tenant,
        'transportId': row['id'],
        ...input,
      }, _gateway.call);
      _check(epoch, uid);
      final confirmed = _map(result['transport']);
      // Older commands may return the stored transport without query projections.
      // Preserve only a known species by stable pet ID; never infer by name/breed.
      confirmed['pets'] = (confirmed['pets'] as List).map((raw) {
        final pet = _map(raw);
        final previous = (row['pets'] as List)
            .map(_map)
            .where(
              (old) =>
                  pet['id'] != null &&
                  pet['id'] != '' &&
                  old['id'] == pet['id'],
            )
            .firstOrNull;
        return {
          ...pet,
          if ((pet['species'] == null || pet['species'] == '') &&
              previous?['species'] != null)
            'species': previous!['species'],
        };
      }).toList();
      final job = _job(confirmed);
      _rows = _rows
          .map(
            (value) => value['tenantId'] == tenant && value['id'] == row['id']
                ? confirmed
                : value,
          )
          .toList();
      try {
        await _cache.patch(uid!, tenant, 'transports', confirmed);
      } catch (_) {
        cacheWarning =
            'Transporte confirmado. Atualize para recuperar a cópia offline.';
        try {
          await _cache.invalidate(uid!, tenant, 'transports');
        } catch (_) {
          /* Confirmed on server; preserve the returned job. */
        }
      }
      _check(epoch, uid);
      return job;
    } on SessionAccessException {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<TransportJob> checkPets(
    String id,
    String phase,
    List<TransportPetCheck> checks,
  ) => _mutate(id, 'checkTransportPets', {
    'phase': phase,
    'checks': checks
        .map(
          (c) => {
            'petId': c.petId,
            'confirmed': c.confirmed,
            'reason': c.reason,
          },
        )
        .toList(),
  });
  @override
  Future<TransportJob> transition(
    String id,
    TransportStatus expectedStatus,
    TransportStatus newStatus,
  ) => _mutate(id, 'transitionTransport', {
    'expectedStatus': expectedStatus.apiValue,
    'status': newStatus.apiValue,
  });
  @override
  Future<TransportJob> addIncident(
    String id,
    String type,
    String description,
  ) => _mutate(id, 'addTransportIncident', {
    'type': type,
    'description': description,
  });
  @override
  Future<void> signOut() {
    ++_epoch;
    _scopes = [];
    _rows = [];
    _offlineCompanies.clear();
    _times.clear();
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
