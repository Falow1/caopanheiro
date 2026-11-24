import 'in_memory/fixtures/transport_fixtures.dart';
import 'package:equipe_app/modules/driver/domain/models.dart';
import 'package:equipe_app/modules/driver/domain/policies/transport_transitions.dart';
import 'package:equipe_app/modules/driver/domain/repositories/transport_repository.dart';

class InMemoryTransportRepository implements TransportRepository {
  InMemoryTransportRepository() {
    _transports = createInitialTransports();
  }

  final _profile = createInitialDriverProfile();
  final _memberships = createInitialMemberships();
  late List<TransportJob> _transports;

  Future<void> _wait() =>
      Future<void>.delayed(const Duration(milliseconds: 260));

  @override
  Future<DriverProfile> signIn(String login, String password) async {
    await _wait();
    if (!login.contains('@') || password.length < 6) {
      throw const FormatException('Credenciais de entregador inválidas.');
    }
    return _profile;
  }

  @override
  Future<List<TenantMembership>> getMemberships() async {
    await _wait();
    return List.unmodifiable(_memberships);
  }

  @override
  Future<List<TransportJob>> getAssignedTransports() async {
    await _wait();
    return List.unmodifiable(_transports);
  }

  @override
  Future<TransportJob> checkPets(
    String id,
    String phase,
    List<TransportPetCheck> checks,
  ) async {
    await _wait();
    final index = _transports.indexWhere((v) => v.id == id);
    final old = _transports[index];
    final next = phase == 'COLLECTION'
        ? old.copyWith(collectionChecks: checks)
        : old.copyWith(deliveryChecks: checks);
    _transports[index] = next;
    return next;
  }

  @override
  Future<TransportJob> transition(
    String transportId,
    TransportStatus expectedStatus,
    TransportStatus newStatus,
  ) async {
    await _wait();
    final index = _transports.indexWhere((item) => item.id == transportId);
    if (index < 0) throw StateError('Transporte não encontrado.');
    final current = _transports[index];
    if (current.status != expectedStatus ||
        !canTransitionTransport(current.status, newStatus)) {
      throw StateError(
        'O transporte foi atualizado. Recarregue e tente novamente.',
      );
    }
    final now = DateTime.now();
    final updated = current.copyWith(
      status: newStatus,
      events: [
        ...current.events,
        TransportEvent(status: newStatus, createdAt: now, actor: _profile.name),
      ],
      startedAt: newStatus == TransportStatus.goingToOrigin ? now : null,
      collectedAt: newStatus == TransportStatus.petCollected ? now : null,
      deliveredAt: newStatus == TransportStatus.delivered ? now : null,
    );
    _transports[index] = updated;
    return updated;
  }

  @override
  Future<TransportJob> addIncident(
    String transportId,
    String type,
    String description,
  ) async {
    await _wait();
    final index = _transports.indexWhere((item) => item.id == transportId);
    if (index < 0) throw StateError('Transporte não encontrado.');
    final current = _transports[index];
    final updated = current.copyWith(
      incidents: [
        ...current.incidents,
        TransportIncident(
          type: type,
          description: description,
          createdAt: DateTime.now(),
          driverName: _profile.name,
        ),
      ],
    );
    _transports[index] = updated;
    return updated;
  }
}
