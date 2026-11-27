import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetExecution, PetPolicy, PetServiceReason;
import 'package:caopanheiro_core/caopanheiro_core.dart';

import '../domain/models/appointment.dart';
import '../domain/models/pet.dart';
import '../domain/models/service.dart';
import '../domain/models/tutor.dart';
import '../domain/policies/tutor_invite.dart';
import '../domain/repositories/petshop_repository.dart';
import '../domain/repositories/login_code_repository.dart';
import '../domain/repositories/tutor_extras_repository.dart';
import '../domain/repositories/tutor_pet_policy.dart';
import '../domain/repositories/tutor_transport_repository.dart';
import '../domain/repositories/tutor_session.dart';
import '../domain/repositories/tutor_address_repository.dart';

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

/// PWA: business data is read through online callables only. No SQL, Firestore
/// persistence, localStorage or background write queue is used by this adapter.
class FirebasePetshopRepository
    implements
        PetshopRepository,
        TutorSession,
        TutorTransportRepository,
        TutorExtrasRepository,
        TutorPetPolicySource,
        AccountDeletionRepository,
        ScreenTipsRepository,
        LiveSignalsAware,
        NetworkProblemSource,
        LoginCodeRepository,
        TutorAddressRepository {
  FirebasePetshopRepository(this._gateway);

  @override
  Future<String> requestLoginCode() async {
    final result = await _gateway.call('requestLoginCode', {});
    return result['challengeId'] as String;
  }

  @override
  Future<void> verifyLoginCode(String challengeId, String code) async {
    await _gateway.call('verifyLoginCode', {
      'challengeId': challengeId,
      'code': code,
    });
  }

  final LocalFirebaseGateway _gateway;

  /// Reason of the latest call without answer, for the read-only banner.
  @override
  NetworkProblem? get lastNetworkProblem => _gateway.lastNetworkProblem;
  @override
  LiveSignalSource? get liveSignals => _gateway.liveSignals;
  final ExplicitCommands _commands = ExplicitCommands();
  List<Map<String, dynamic>> _scopes = [];
  List<String> _paused = const [];
  @override
  List<String> get pausedCompanies => _paused;
  bool _principalManager = false;
  @override
  bool get principalManager => _principalManager;

  // Screen tips of the account, from the same context. Null when the server
  // did not send them: then no tip is offered.
  ScreenTips? _screenTips;
  @override
  ScreenTips? get screenTips => _screenTips;

  Future<void> _updateScreenTips(
    ScreenTips Function(ScreenTips) local,
    Map<String, dynamic> data,
  ) async {
    final tips = _screenTips;
    if (tips == null) return;
    _screenTips = local(tips);
    await _gateway.call('updateScreenTips', data);
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

  Map<String, dynamic>? _profile;
  String? _selected;
  String? _pendingSignupUid;
  String? _pendingSignupEmail;
  int _epoch = 0;
  Future<void> _ending = Future.value();
  @override
  Future<void> deleteOwnAccount(String password) async {
    await _gateway.call('deleteOwnAccount', {
      'requestId': newRecordId(),
      'password': password,
      'confirmed': true,
    });
    await signOut();
  }

  @override
  bool get emailVerified => _gateway.emailVerified;
  @override
  String? get selectedCompanyId => _selected;
  @override
  List<TutorCompany> get companies => _scopes
      .map(
        (s) => TutorCompany(
          s['id'] as String,
          s['name'] as String,
          readOnly: s['readOnly'] == true,
          contactPhone: s['contactPhone'] as String? ?? '',
          bookingPaused: s['bookingPaused'] == true,
          bookingNoticeFrom: s['bookingNotice'] is Map
              ? DateTime.tryParse(
                  (s['bookingNotice'] as Map)['from'] as String? ?? '',
                )?.toLocal()
              : null,
        ),
      )
      .toList();
  Map<String, dynamic> get _company => _scopes.firstWhere(
    (s) => s['id'] == _selected,
    orElse: () =>
        throw const FormatException('Selecione uma empresa vinculada.'),
  );
  String get _customerId => _map(_company['profile'])['customerId'] as String;
  Tutor _tutor(Map<String, dynamic> value) => Tutor(
    recordNumber: readRecordNumber(value['recordNumber']),
    name: value['name'] as String,
    phone: value['phone'] as String? ?? '',
    email: value['email'] as String,
  );
  void _check(int epoch, String? uid, String? company) {
    if (epoch != _epoch ||
        uid == null ||
        uid != _gateway.uid ||
        company != _selected) {
      throw const SessionChangedException('Sessão ou empresa alterada.');
    }
  }

  @override
  Future<Tutor> refreshContext() async {
    final epoch = _epoch;
    final uid = _gateway.uid;
    final selected = _selected;
    await _gateway.reloadIdentity();
    final response = await _gateway.call('getApplicationContext', {
      'role': 'TUTOR',
    });
    _check(epoch, uid, selected);
    if (response['uid'] != uid) {
      throw const SessionAccessException('Identidade divergente.');
    }
    final previous = _scopes;
    _scopes = (response['companies'] as List).map(_map).toList();
    _paused = ((response['unavailableCompanies'] as List?) ?? const [])
        .map((item) => _map(item)['name'] as String? ?? 'empresa')
        .toList();
    _principalManager = response['principalManager'] == true;
    _screenTips = ScreenTips.fromJson(response['screenTips']);
    _profile = _map(response['profile']);
    if (selected != null && !_scopes.any((s) => s['id'] == selected)) {
      // Only this petshop lost access; the account and other links stay.
      _removedCompany =
          previous.where((s) => s['id'] == selected).firstOrNull?['name']
              as String? ??
          'empresa';
      ++_epoch;
      _selected = null;
    }
    if (_selected == null && _scopes.length == 1) {
      _selected = _scopes.single['id'] as String;
    }
    _commands.clear();
    return _tutor(_selected == null ? _profile! : _map(_company['profile']));
  }

  @override
  Future<Tutor> signIn(String identifier, String password) async {
    await _ending;
    await signOut();
    try {
      await _gateway.signIn(identifier, password);
      return await refreshContext();
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<Tutor> signUp(Tutor tutor, String password) async {
    await _ending;
    final resume =
        _pendingSignupUid != null &&
        _pendingSignupUid == _gateway.uid &&
        _pendingSignupEmail == tutor.email.trim().toLowerCase();
    if (!resume) {
      await signOut();
      final creationEpoch = _epoch;
      await _gateway.signUp(tutor.email, password, tutor.name);
      if (creationEpoch != _epoch) {
        throw const SessionChangedException(
          'Sessão alterada durante o cadastro.',
        );
      }
      _pendingSignupUid = _gateway.uid;
      _pendingSignupEmail = tutor.email.trim().toLowerCase();
    }
    final epoch = _epoch, uid = _gateway.uid;
    try {
      await _gateway.call('saveTutorAccountProfile', {
        'name': tutor.name,
        'phone': tutor.phone,
      });
      _check(epoch, uid, null);
      final profile = await refreshContext();
      _pendingSignupUid = null;
      _pendingSignupEmail = null;
      return profile;
    } on SessionAccessException {
      if (epoch == _epoch) await signOut();
      rethrow;
    } on NetworkException catch (error) {
      // Explicit retry reuses this identity; it never creates a second account.
      throw NetworkException(
        'Sua conta foi criada. Não foi possível '
        'confirmar o perfil. Tente novamente com o mesmo e-mail.',
        error.problem,
      );
    }
  }

  @override
  Future<Tutor?> restore() async {
    if (_gateway.uid == null) return null;
    try {
      return await refreshContext();
    } on SessionAccessException {
      await signOut();
      return null;
    } on NetworkException {
      return null;
    }
  }

  @override
  Future<Tutor> selectCompany(String id) async {
    if (!companies.any((company) => company.id == id)) {
      throw const SessionAccessException('Empresa indisponível.');
    }
    ++_epoch;
    _commands.clear();
    _selected = id;
    return refreshContext();
  }

  @override
  Future<TutorLinkResult> acceptLink(String code) async {
    // Invite has its own one-time transaction; it does not grant roles locally.
    await _gateway.reloadIdentity();
    final response = await _gateway.call('acceptTutorLink', {
      'code': code.trim(),
    });
    await refreshContext();
    return response['pending'] == true
        ? TutorLinkResult.pending
        : TutorLinkResult.linked;
  }

  @override
  bool get accountContactComplete {
    final profile = _profile;
    if (profile == null) return true;
    return validContactName(profile['name'] as String? ?? '') &&
        validContactPhone(profile['phone'] as String? ?? '');
  }

  @override
  Future<Tutor> saveAccountContact(String name, String phone) async {
    final epoch = _epoch, uid = _gateway.uid, selected = _selected;
    await _gateway.call('saveTutorAccountProfile', {
      'name': name.trim(),
      'phone': phone.trim(),
    });
    _check(epoch, uid, selected);
    return refreshContext();
  }

  @override
  Future<void> sendVerification() => _gateway.sendVerification();
  @override
  Future<void> sendPasswordReset(String email) =>
      _gateway.sendPasswordReset(email);
  @override
  List<String> get providers => _gateway.providers;
  @override
  Future<Tutor> signInWithGoogle() async {
    await _ending;
    await signOut();
    try {
      await _gateway.signInWithGoogle();
      return await refreshContext();
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<void> linkGoogle() => _gateway.linkGoogle();
  String? _removedCompany;
  @override
  String? takeRemovedCompany() {
    final name = _removedCompany;
    _removedCompany = null;
    return name;
  }

  Future<List<Map<String, dynamic>>> _read(String resource) async {
    final epoch = _epoch;
    final uid = _gateway.uid;
    final tenant = _selected;
    if (tenant == null) return [];
    try {
      final rows = <Map<String, dynamic>>[];
      String? cursor;
      do {
        final page = await _gateway.call('getProfileData', {
          'tenantId': tenant,
          'role': 'TUTOR',
          'resource': resource,
          'cursor': cursor,
        });
        _check(epoch, uid, tenant);
        // The rule of pets comes with the customer record of the petshop.
        if (resource == 'customer') {
          _petPolicy = PetPolicy.fromJson(page['petPolicy']);
        }
        rows.addAll((page['items'] as List).map(_map));
        cursor = page['nextCursor'] as String?;
      } while (cursor != null);
      return rows;
    } on SessionAccessException {
      // The controller decides: lost petshop link keeps the account,
      // an invalid identity ends the session.
      rethrow;
    }
  }

  PetPolicy _petPolicy = const PetPolicy();
  @override
  PetPolicy get petPolicy => _petPolicy;

  Pet _pet(Map<String, dynamic> value) {
    final service = value['service'] is Map ? _map(value['service']) : null;
    return Pet(
      id: value['id'] as String,
      recordNumber: readRecordNumber(value['recordNumber']),
      name: value['name'] as String,
      species: value['species'] as String,
      breed: value['breed'] as String,
      size: value['size'] as String,
      birthDate: DateTime.parse(value['birthDate'] as String),
      notes: value['notes'] as String? ?? '',
      breedCode: value['breedCode'] as String?,
      legacyBreed: value['legacyBreed'] as String?,
      breedPending: value['breedPending'] == true,
      serviceReason: service == null || service['served'] != false
          ? null
          : PetServiceReason.fromWire(service['reason']) ??
                PetServiceReason.breed,
    );
  }

  @override
  Future<List<Pet>> getPets() async {
    final customer = await _read('customer');
    if (customer.isEmpty) return [];
    return (customer.single['pets'] as List)
        .map((item) => _pet(_map(item)))
        .toList();
  }

  @override
  Future<List<PetService>> getServices() async => (await _read('services'))
      .map(
        (v) => PetService(
          id: v['id'] as String,
          recordNumber: readRecordNumber(v['recordNumber']),
          name: v['name'] as String,
          description: v['description'] as String,
          price: (v['priceCents'] as num) / 100,
          durationMinutes: v['durationMinutes'] as int,
        ),
      )
      .toList();
  Appointment _appointment(Map<String, dynamic> v) => Appointment(
    id: v['id'] as String,
    recordNumber: readRecordNumber(v['recordNumber']),
    companyId: _selected,
    startsAt: DateTime.parse(v['startsAt'] as String).toLocal(),
    companyStartsAt: v['localStartsAt'] == null
        ? null
        : DateTime.parse(v['localStartsAt'] as String),
    professionalId: v['professionalId'] as String?,
    distribution: v['distribution'] as String?,
    scheduleMinutes: (v['scheduleMinutes'] as num?)?.toInt(),
    transport: v['transport'] == null ? null : _map(v['transport']),
    tutorNotes: v['tutorNotes'] as String? ?? '',
    observations: ((v['observations'] as List?) ?? const []).map((item) {
      final o = _map(item);
      return PetObservation(
        petId: o['petId'] as String? ?? '',
        text: o['text'] as String? ?? '',
        at: DateTime.tryParse(o['createdAt'] as String? ?? '')?.toLocal(),
      );
    }).toList(),
    status: AppointmentStatus.fromApi(v['status'] as String),
    items: (v['items'] as List).map((item) {
      final i = _map(item);
      final pet = _map(i['pet']);
      final services = (i['services'] as List).map(_map).toList();
      return AppointmentItem(
        petId: pet['id'] as String,
        execution: PetExecution.fromJson(
          i['execution'],
          AppointmentStatus.fromApi(v['status'] as String),
        ),
        petName: pet['name'] as String,
        serviceIds: services.map((s) => s['id'] as String).toList(),
        serviceNames: services.map((s) => s['name'] as String).toList(),
        price:
            services.fold<int>(
              0,
              (total, s) => total + (s['priceCents'] as int),
            ) /
            100,
        durationMinutes: services.fold<int>(
          0,
          (total, s) => total + (s['durationMinutes'] as int),
        ),
        professionalName: i['professional'] as String?,
        startsAt: DateTime.tryParse(i['startsAt'] as String? ?? '')?.toLocal(),
        endsAt: DateTime.tryParse(i['endsAt'] as String? ?? '')?.toLocal(),
      );
    }).toList(),
    history: ((v['history'] as List?) ?? []).map((item) {
      final e = _map(item);
      return StatusEvent(
        status: AppointmentStatus.fromApi(e['status'] as String),
        at: DateTime.parse(e['at'] as String).toLocal(),
      );
    }).toList(),
  );
  @override
  Future<List<Appointment>> getAppointments() async =>
      (await _read('appointments')).map(_appointment).toList();
  Future<Map<String, dynamic>> _write(
    String name,
    Map<String, dynamic> input,
  ) async {
    final epoch = _epoch;
    final uid = _gateway.uid;
    final tenant = _selected;
    if (tenant == null) {
      throw const FormatException('Selecione uma empresa vinculada.');
    }
    try {
      final response = await _commands.run(name, {
        'tenantId': tenant,
        ...input,
      }, _gateway.call);
      _check(epoch, uid, tenant);
      return response;
    } on SessionAccessException {
      // The controller decides: lost petshop link keeps the account,
      // an invalid identity ends the session.
      rethrow;
    }
  }

  @override
  Future<Tutor> updateTutor(Tutor tutor) async {
    final response = await _write('updateTutorProfile', {
      'name': tutor.name,
      'phone': tutor.phone,
      'email': tutor.email,
    });
    return _tutor(_map(response['tutor']));
  }

  @override
  Future<void> savePet(Pet pet) async {
    await _write('saveTutorPet', {
      'petId': pet.id,
      'pet': {
        'name': pet.name,
        'species': pet.species,
        // The breed of the list; the server derives its name and size.
        if (pet.breedCode != null)
          'breedCode': pet.breedCode
        else ...{
          'breed': pet.breed,
          'size': pet.size,
        },
        if (pet.breedSuggestion != null) 'breedSuggestion': pet.breedSuggestion,
        'birthDate':
            '${pet.birthDate.year.toString().padLeft(4, '0')}-${pet.birthDate.month.toString().padLeft(2, '0')}-${pet.birthDate.day.toString().padLeft(2, '0')}',
        'notes': pet.notes,
      },
    });
  }

  @override
  Future<Appointment> createAppointment(Appointment appointment) async {
    if (appointment.companyId != _selected) {
      throw const FormatException('A empresa mudou. Reinicie o agendamento.');
    }
    final response = await _write('saveAppointment', {
      'appointmentId': appointment.id,
      'customerId': _customerId,
      'expectedPriceCents': (appointment.totalPrice * 100).round(),
      'expectedDurationMinutes': appointment.totalDuration,
      'expectedServices': appointment.expectedServices,
      'startsAt': appointment.startsAt.toUtc().toIso8601String(),
      // With a distribution the professional goes per pet, never for all.
      if (appointment.distribution == null)
        'professionalId': appointment.professionalId
      else ...{
        'distribution': appointment.distribution,
        'assignments': ?appointment.assignments,
      },
      'items': appointment.items
          .map((item) => {'petId': item.petId, 'serviceIds': item.serviceIds})
          .toList(),
      'tutorNotes': appointment.tutorNotes,
      if (appointment.transportQuoteId != null)
        'transportQuoteId': appointment.transportQuoteId,
    });
    return _appointment(_map(response['appointment']));
  }

  @override
  Future<Appointment> cancelAppointment(String id) async {
    final response = await _write('updateAppointmentStatus', {
      'appointmentId': id,
      'status': 'CANCELLED',
    });
    return _appointment(_map(response['appointment']));
  }

  @override
  Future<List<TutorSlot>> availableSlots(
    String day,
    List<Map<String, dynamic>> items, {
    String? distribution,
  }) async {
    final epoch = _epoch;
    final uid = _gateway.uid;
    final tenant = _selected;
    final response = await _gateway.call('getAvailableSlots', {
      'tenantId': tenant,
      'customerId': _customerId,
      'day': day,
      'items': items,
      'distribution': ?distribution,
    });
    _check(epoch, uid, tenant);
    return (response['slots'] as List)
        .map((item) => _slot(_map(item)))
        .toList();
  }

  TutorSlot _slot(Map<String, dynamic> v) => TutorSlot(
    startsAt: DateTime.parse(v['startsAt'] as String),
    label: v['label'] as String,
    professionalId: v['professionalId'] as String,
    professionalName: v['professionalName'] as String,
    endsAt: v['endsAt'] == null ? null : DateTime.parse(v['endsAt'] as String),
    minutes: (v['minutes'] as num?)?.toInt(),
    assignments: ((v['assignments'] as List?) ?? const []).map((raw) {
      final a = _map(raw);
      return SlotAssignment(
        petId: a['petId'] as String,
        professionalId: a['professionalId'] as String,
        professionalName: a['professionalName'] as String? ?? 'Profissional',
        startsAt: DateTime.parse(a['startsAt'] as String),
        endsAt: DateTime.parse(a['endsAt'] as String),
      );
    }).toList(),
    professionals: ((v['professionals'] as List?) ?? const []).map((raw) {
      final p = _map(raw);
      return SlotProfessional(
        p['id'] as String,
        p['name'] as String? ?? 'Profissional',
        (p['freeMinutes'] as num).toInt(),
      );
    }).toList(),
  );

  Future<Map<String, dynamic>> _transportQuery(
    String name,
    Map<String, dynamic> input,
  ) async {
    final epoch = _epoch, uid = _gateway.uid, company = _selected;
    if (company == null) throw const FormatException('Selecione uma empresa.');
    try {
      final result = await _gateway.call(name, {'tenantId': company, ...input});
      _check(epoch, uid, company);
      return result;
    } on SessionAccessException {
      // The controller decides: lost petshop link keeps the account,
      // an invalid identity ends the session.
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> transportPolicy() async =>
      _map((await _transportQuery('getTransportPolicy', {}))['policy']);
  @override
  Future<List<Map<String, dynamic>>> searchTransportAddress(
    String query,
  ) async =>
      ((await _transportQuery('searchTransportAddress', {
                'query': query,
              }))['places']
              as List)
          .map(_map)
          .toList();
  @override
  Future<Map<String, dynamic>> quoteTransport(
    bool pickup,
    bool returnTrip,
    Map<String, dynamic> location,
  ) async => _map(
    (await _transportQuery('quoteTutorTransport', {
      'pickup': pickup,
      'returnTrip': returnTrip,
      'location': location,
    }))['quote'],
  );
  @override
  Future<Map<String, dynamic>> trackTransport(String appointmentId) =>
      _transportQuery('getTutorTransportTracking', {
        'appointmentId': appointmentId,
      });
  @override
  Future<TutorNoticePage> notices() async {
    final page = await _transportQuery('getNotices', {'role': 'TUTOR'});
    return TutorNoticePage(
      (page['items'] as List).map(_map).toList(),
      (page['unread'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> markNoticesSeen() async {
    await _transportQuery('markNoticesSeen', {'role': 'TUTOR'});
  }

  @override
  Future<List<TutorSlot>> rescheduleSlots(
    String day,
    List<Map<String, dynamic>> items,
    String appointmentId, {
    String? distribution,
  }) async {
    final response = await _transportQuery('getAvailableSlots', {
      'distribution': ?distribution,
      'customerId': _customerId,
      'day': day,
      'items': items,
      'appointmentId': appointmentId,
    });
    return (response['slots'] as List)
        .map((item) => _slot(_map(item)))
        .toList();
  }

  @override
  TutorAddress? get savedAddress => TutorAddress.fromJson(_profile?['address']);

  @override
  Future<TutorAddress?> saveAddress(TutorAddress? address) async {
    final epoch = _epoch, uid = _gateway.uid, selected = _selected;
    final response = await _gateway.call('saveTutorAddress', {
      'address': address?.toJson(),
    });
    _check(epoch, uid, selected);
    final saved = TutorAddress.fromJson(response['address']);
    _profile = {...?_profile, 'address': saved?.toJson()};
    return saved;
  }

  @override
  Future<ReversedAddress?> reverseAddress(double lat, double lng) async {
    final result = await _transportQuery('reverseTransportAddress', {
      'point': {'lat': lat, 'lng': lng},
    });
    final place = result['place'];
    if (place is! Map) return null;
    return ReversedAddress(
      street: place['street'] as String? ?? '',
      district: place['district'] as String? ?? '',
    );
  }

  @override
  Future<void> requestTransport(String appointmentId, String quoteId) async {
    await _write('requestTutorTransport', {
      'appointmentId': appointmentId,
      'transportQuoteId': quoteId,
    });
  }

  @override
  Future<void> signOut() {
    ++_epoch;
    _scopes = [];
    _paused = const [];
    _principalManager = false;
    _screenTips = null;
    _profile = null;
    _selected = null;
    _pendingSignupUid = null;
    _pendingSignupEmail = null;
    _removedCompany = null;
    _commands.clear();
    _ending = _ending.catchError((Object _) {}).then((_) => _gateway.signOut());
    return _ending;
  }
}
