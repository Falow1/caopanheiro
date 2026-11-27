import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetExecution;
import 'package:caopanheiro_core/caopanheiro_core.dart';

import '../domain/models.dart';
import '../domain/repositories/professional_repository.dart';
import '../domain/repositories/professional_session.dart';
import 'package:equipe_app/domain/repositories/team_extras_repository.dart';

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

class FirebaseProfessionalRepository
    implements
        ProfessionalRepository,
        ProfessionalSession,
        AttachedSession,
        RoleNoticesSource,
        LiveSignalsAware,
        NetworkProblemSource {
  FirebaseProfessionalRepository(this._gateway, this._cache);
  @override
  LiveSignalSource? get liveSignals => _gateway.liveSignals;
  @override
  Future<Map<String, dynamic>> roleNotices(String tenantId) => _gateway.call(
    'getNotices',
    {'tenantId': tenantId, 'role': 'PROFESSIONAL'},
  );
  @override
  Future<void> markRoleNoticesSeen(String tenantId) async {
    await _gateway.call('markNoticesSeen', {
      'tenantId': tenantId,
      'role': 'PROFESSIONAL',
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
  String? _selected;
  int _epoch = 0;
  Future<void> _ending = Future.value();
  @override
  bool readOnly = false;
  @override
  DateTime? updatedAt;
  @override
  String? cacheWarning;
  @override
  String? get selectedCompanyId => _selected;
  @override
  List<ProfessionalCompany> get companies => _scopes
      .where((s) => _unifiedTenant == null || s['id'] == _unifiedTenant)
      .map(
        (scope) => ProfessionalCompany(
          scope['id'] as String,
          scope['name'] as String,
          _profile(_map(scope['profile'])),
        ),
      )
      .toList();
  Professional _profile(Map<String, dynamic> value) => Professional(
    id: value['id'] as String,
    recordNumber: readRecordNumber(value['recordNumber']),
    name: value['name'] as String,
    role: value['role'] as String? ?? 'Profissional',
    email: value['email'] as String? ?? '',
    phone: value['phone'] as String? ?? '',
  );
  void _check(int epoch, String? uid) {
    if (epoch != _epoch || uid == null || uid != _gateway.uid) {
      throw const SessionChangedException('Sessão encerrada.');
    }
  }

  Future<void> _context() async {
    final epoch = _epoch;
    final uid = _gateway.uid;
    final response = await _gateway.call('getApplicationContext', {
      'role': 'PROFESSIONAL',
    });
    _check(epoch, uid);
    if (response['uid'] != uid) {
      throw const SessionAccessException('Identidade divergente.');
    }
    final scopes = (response['companies'] as List).map(_map).toList();
    if (scopes.isEmpty) {
      throw const SessionAccessException('Sem empresa autorizada.');
    }
    await _cache.bind(uid!, scopes);
    _check(epoch, uid);
    _scopes = scopes;
    if (_selected != null && !scopes.any((scope) => scope['id'] == _selected)) {
      throw const SessionAccessException(
        'O vínculo com a empresa foi removido.',
      );
    }
    readOnly = false;
  }

  @override
  Future<Professional> attachCompany(String id) async {
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
      readOnly = true;
    }
    if (!_scopes.any((s) => s['id'] == id)) {
      throw const SessionAccessException('Função removida neste petshop.');
    }
    _selected = id;
    return companies.firstWhere((c) => c.id == id).professional;
  }

  @override
  void detachView() {
    ++_epoch;
    _commands.clear();
    _rows = [];
    _scopes = [];
    _unifiedTenant = null;
    _selected = null;
    readOnly = false;
    updatedAt = null;
    cacheWarning = null;
  }

  @override
  Future<Professional> signIn(String identifier, String password) async {
    await _ending;
    await signOut();
    await _ending;
    try {
      await _gateway.signIn(identifier, password);
      await _context();
      if (_scopes.length == 1) _selected = _scopes.single['id'] as String;
      return companies.first.professional;
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<Professional?> restore() async {
    final uid = _gateway.uid;
    if (uid == null || await _cache.owner != uid) {
      await _cache.clear();
      return null;
    }
    try {
      await _context();
    } on NetworkException {
      _scopes = await _cache.scopes(uid);
      readOnly = true;
    } on SessionAccessException {
      await signOut();
      return null;
    }
    if (_scopes.isEmpty) return null;
    if (_scopes.length == 1) _selected = _scopes.single['id'] as String;
    return companies.first.professional;
  }

  @override
  Future<Professional> selectCompany(String id) async {
    if (!companies.any((company) => company.id == id)) {
      throw const SessionAccessException('Empresa indisponível.');
    }
    ++_epoch;
    _commands.clear();
    _selected = id;
    _rows = [];
    updatedAt = null;
    return companies.firstWhere((company) => company.id == id).professional;
  }

  @override
  Future<List<Appointment>> getAppointments(String professionalId) async {
    final epoch = _epoch;
    final uid = _gateway.uid;
    final tenant = _selected;
    if (tenant == null) return [];
    try {
      await _context();
      _check(epoch, uid);
      final rows = <Map<String, dynamic>>[];
      String? cursor;
      do {
        final response = await _gateway.call('getProfileData', {
          'tenantId': tenant,
          'role': 'PROFESSIONAL',
          'resource': 'appointments',
          'cursor': cursor,
        });
        _check(epoch, uid);
        if (tenant != _selected) {
          throw const SessionChangedException('Empresa alterada.');
        }
        rows.addAll((response['items'] as List).map(_map));
        cursor = response['nextCursor'] as String?;
      } while (cursor != null);
      final confirmed = rows.map(_appointment).toList();
      final now = DateTime.now();
      await _cache.write(uid!, tenant, 'appointments', rows, updatedAt: now);
      _check(epoch, uid);
      _commands.clear();
      _rows = rows;
      updatedAt = now;
      readOnly = false;
      cacheWarning = null;
      return confirmed;
    } on NetworkException {
      _check(epoch, uid);
      final snapshot = await _cache.read(uid!, tenant, 'appointments');
      _check(epoch, uid);
      if (snapshot == null) rethrow;
      _rows = snapshot.items;
      updatedAt = snapshot.updatedAt;
      readOnly = true;
      return _rows.map(_appointment).toList();
    } on SessionAccessException {
      await signOut();
      rethrow;
    }
  }

  Appointment _appointment(Map<String, dynamic> row) {
    final pet = _map(row['pet']);
    return Appointment(
      id: row['id'] as String,
      recordNumber: readRecordNumber(row['recordNumber']),
      startsAt: DateTime.parse(row['startsAt'] as String).toLocal(),
      companyStartsAt: row['localStartsAt'] == null
          ? null
          : DateTime.parse(row['localStartsAt'] as String),
      pet: Pet(
        id: pet['id'] as String,
        recordNumber: readRecordNumber(pet['recordNumber']),
        name: pet['name'] as String,
        species: pet['species'] as String? ?? '',
        breedCode: pet['breedCode'] as String?,
        breed: pet['breed'] as String,
        size: pet['size'] as String,
        notes: pet['notes'] as String? ?? '',
      ),
      services: (row['services'] as List).map((item) {
        final value = _map(item);
        return ServiceItem(
          name: value['name'] as String,
          durationMinutes: value['durationMinutes'] as int,
        );
      }).toList(),
      status: AppointmentStatus.fromApi(row['status'] as String),
      tutorName: row['tutorName'] as String,
      execution: PetExecution.fromJson(
        row['execution'],
        AppointmentStatus.fromApi(row['status'] as String),
      ),
      notes: row['notes'] as String? ?? '',
      tutorNotes: row['tutorNotes'] as String? ?? '',
      observations: ((row['observations'] as List?) ?? []).map((item) {
        final value = _map(item);
        return ServiceObservation(
          text: value['text'] as String,
          createdAt: DateTime.parse(value['createdAt'] as String).toLocal(),
        );
      }).toList(),
    );
  }

  Future<void> _mutate(
    String id,
    String command,
    Map<String, dynamic> input,
  ) async {
    if (readOnly) {
      throw const FormatException(
        'Conecte-se e atualize para alterar um atendimento.',
      );
    }
    final row = _rows.where((row) => row['id'] == id).firstOrNull;
    if (row == null) {
      throw const FormatException('Atualize a agenda antes de continuar.');
    }
    final epoch = _epoch;
    final uid = _gateway.uid;
    final tenant = _selected!;
    try {
      final response = await _commands.run(command, {
        'tenantId': tenant,
        'appointmentId': row['appointmentId'],
        ...input,
      }, _gateway.call);
      _check(epoch, uid);
      if (tenant != _selected) {
        throw const SessionChangedException('Empresa alterada.');
      }
      final confirmed = _map(response['appointment']);
      _rows = _rows
          .map(
            (old) => old['appointmentId'] != row['appointmentId']
                ? old
                : {
                    ...old,
                    'status': (confirmed['items'] as List)
                        .map(_map)
                        .firstWhere(
                          (item) =>
                              _map(item['pet'])['id'] == _map(old['pet'])['id'],
                        )['execution']['status'],
                    'execution': (confirmed['items'] as List)
                        .map(_map)
                        .firstWhere(
                          (item) =>
                              _map(item['pet'])['id'] == _map(old['pet'])['id'],
                        )['execution'],
                    'appointmentStatus': confirmed['status'],
                    if (confirmed.containsKey('notes'))
                      'notes': confirmed['notes'] as String? ?? '',
                    'observations': ((confirmed['observations'] as List?) ?? [])
                        .map(_map)
                        .where(
                          (value) => value['petId'] == _map(old['pet'])['id'],
                        )
                        .toList(),
                  },
          )
          .toList();
      try {
        for (final item in _rows.where(
          (value) => value['appointmentId'] == row['appointmentId'],
        )) {
          _check(epoch, uid);
          await _cache.patch(uid!, tenant, 'appointments', item);
        }
      } on SessionChangedException {
        rethrow;
      } catch (_) {
        _check(epoch, uid);
        cacheWarning =
            'Alteração confirmada. Atualize para recuperar a cópia offline.';
        try {
          await _cache.invalidate(uid!, tenant, 'appointments');
        } catch (_) {
          /* Preserve the confirmed server result. */
        }
      }
    } on SessionAccessException {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<void> updateStatus(String id, AppointmentStatus status) {
    final row = _rows.where((value) => value['id'] == id).firstOrNull;
    if (row == null) {
      throw const FormatException(
        'Atendimento indisponível. Atualize a agenda.',
      );
    }
    return _mutate(id, 'updateAppointmentStatus', {
      'status': status.apiValue,
      'petId': _map(row['pet'])['id'],
    });
  }

  @override
  Future<void> addObservation(String id, ServiceObservation observation) {
    final row = _rows.where((value) => value['id'] == id).firstOrNull;
    if (row == null) throw const FormatException('Atendimento indisponível.');
    return _mutate(id, 'addServiceObservation', {
      'petId': _map(row['pet'])['id'],
      'text': observation.text,
    });
  }

  @override
  List<Appointment> get confirmedAppointments =>
      _rows.map(_appointment).toList();
  @override
  Future<void> signOut() {
    ++_epoch;
    _scopes = [];
    _rows = [];
    _selected = null;
    readOnly = false;
    updatedAt = null;
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
