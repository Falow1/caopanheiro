import 'in_memory/fixtures/petshop_fixtures.dart';
import 'package:tutor_app/domain/models/appointment.dart';
import 'package:tutor_app/domain/models/pet.dart';
import 'package:tutor_app/domain/models/service.dart';
import 'package:tutor_app/domain/models/tutor.dart';
import 'package:tutor_app/domain/repositories/petshop_repository.dart';

class InMemoryPetshopRepository implements PetshopRepository {
  Tutor _tutor = createInitialTutor();
  final List<Pet> _pets = createInitialPets();
  final List<PetService> _services = createInitialServices();

  late final List<Appointment> _appointments = createInitialAppointments();

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 250));

  @override
  Future<Tutor> signIn(String identifier, String password) async {
    await _latency();
    if (identifier.trim().isEmpty || password.length < 4) {
      throw const FormatException(
        'Confira seu e-mail ou telefone e tente novamente.',
      );
    }
    return _tutor;
  }

  @override
  Future<Tutor> signUp(Tutor tutor, String password) async {
    await _latency();
    if (password.length < 6) {
      throw const FormatException('Use uma senha com pelo menos 6 caracteres.');
    }
    _tutor = tutor;
    return tutor;
  }

  @override
  Future<Tutor> updateTutor(Tutor tutor) async {
    await _latency();
    _tutor = tutor;
    return tutor;
  }

  @override
  Future<List<Pet>> getPets() async {
    await _latency();
    return List.unmodifiable(_pets);
  }

  @override
  Future<List<PetService>> getServices() async {
    await _latency();
    return List.unmodifiable(_services);
  }

  @override
  Future<List<Appointment>> getAppointments() async {
    await _latency();
    return List.unmodifiable(_appointments);
  }

  @override
  Future<void> savePet(Pet pet) async {
    await _latency();
    final index = _pets.indexWhere((item) => item.id == pet.id);
    if (index == -1) {
      _pets.add(pet);
    } else {
      _pets[index] = pet;
    }
  }

  @override
  Future<Appointment> createAppointment(Appointment appointment) async {
    await _latency();
    _appointments.add(appointment);
    return appointment;
  }

  @override
  Future<Appointment> cancelAppointment(String id) async {
    await _latency();
    final index = _appointments.indexWhere((item) => item.id == id);
    if (index == -1) throw const FormatException('Agendamento não encontrado.');
    final updated = _appointments[index].copyWith(
      status: AppointmentStatus.cancelled,
      history: [
        ..._appointments[index].history,
        StatusEvent(status: AppointmentStatus.cancelled, at: DateTime.now()),
      ],
    );
    _appointments[index] = updated;
    return updated;
  }
}
