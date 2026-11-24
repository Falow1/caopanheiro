import 'in_memory/fixtures/professional_fixtures.dart';
import 'package:equipe_app/modules/professional/domain/models.dart';
import 'package:equipe_app/modules/professional/domain/repositories/professional_repository.dart';

class InMemoryProfessionalRepository implements ProfessionalRepository {
  final Professional _professional = createInitialProfessional();

  late final List<Appointment> _appointments = createInitialAppointments();

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 240));

  @override
  Future<Professional> signIn(String identifier, String password) async {
    await _latency();
    if (identifier.trim().isEmpty || password.length < 4) {
      throw const FormatException('Usuário ou senha inválidos.');
    }
    return _professional;
  }

  @override
  Future<List<Appointment>> getAppointments(String professionalId) async {
    await _latency();
    return List.unmodifiable(_appointments);
  }

  @override
  Future<void> updateStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    await _latency();
    final index = _appointments.indexWhere((item) => item.id == appointmentId);
    if (index < 0) {
      throw const FormatException('Atendimento não encontrado.');
    }
    _appointments[index] = _appointments[index].copyWith(status: status);
  }

  @override
  Future<void> addObservation(
    String appointmentId,
    ServiceObservation observation,
  ) async {
    await _latency();
    final index = _appointments.indexWhere((item) => item.id == appointmentId);
    if (index < 0) {
      throw const FormatException('Atendimento não encontrado.');
    }
    _appointments[index] = _appointments[index].copyWith(
      observations: [..._appointments[index].observations, observation],
    );
  }
}
