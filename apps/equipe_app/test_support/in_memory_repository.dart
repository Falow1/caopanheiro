import 'in_memory/fixtures/internal_fixtures.dart';
import 'package:equipe_app/domain/repositories/scheduling_repository.dart';
import 'package:equipe_app/domain/repositories/internal_repository.dart';
import 'package:equipe_app/domain/models.dart';
import 'package:equipe_app/domain/models/team_company.dart';

class InMemoryRepository
    implements InternalRepository, AppointmentNotesRepository {
  @override
  Future<List<TeamCompany>> getCompanies() async => const [];
  @override
  Future<InternalUser> selectCompany(String id) => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
  final _bath = createInitialBath();
  final _groom = createInitialGroom();
  final _nails = createInitialNails();
  late final List<PetService> _services = createInitialServices(
    _bath,
    _groom,
    _nails,
  );
  late final List<Customer> _customers = createInitialCustomers();
  late final List<Appointment> _appointments = createInitialAppointments(
    _customers,
    _bath,
    _groom,
    _nails,
  );
  final List<Professional> _professionals = createInitialProfessionals();
  final List<ScheduleBlock> _blocks = createInitialBlocks();

  Future<void> _wait() =>
      Future<void>.delayed(const Duration(milliseconds: 220));
  @override
  Future<InternalUser> signIn(String identifier, String password) async {
    await _wait();
    if (identifier.trim().isEmpty || password.length < 4) {
      throw const FormatException('Identificação ou senha inválida.');
    }
    if (identifier.toLowerCase().contains('atendente')) {
      return const InternalUser(
        name: 'Paula Nunes',
        role: TenantRole.attendant,
        canManageBlocks: true,
      );
    }
    return const InternalUser(
      name: 'Rafael Costa',
      role: TenantRole.manager,
      canManageServices: true,
      canManageBlocks: true,
      canRunService: true,
    );
  }

  @override
  Future<List<Customer>> getCustomers() async {
    await _wait();
    return List.unmodifiable(_customers);
  }

  @override
  Future<List<PetService>> getServices() async {
    await _wait();
    return List.unmodifiable(_services);
  }

  @override
  Future<List<Appointment>> getAppointments() async {
    await _wait();
    return List.unmodifiable(_appointments);
  }

  @override
  Future<List<Professional>> getProfessionals() async {
    await _wait();
    return List.unmodifiable(_professionals);
  }

  @override
  Future<List<ScheduleBlock>> getBlocks() async {
    await _wait();
    return List.unmodifiable(_blocks);
  }

  @override
  Future<Customer> saveCustomer(Customer customer) async {
    await _wait();
    final index = _customers.indexWhere((item) => item.id == customer.id);
    if (index < 0) {
      _customers.add(customer);
    } else {
      _customers[index] = customer;
    }
    return customer;
  }

  @override
  Future<Customer> savePet(String customerId, Pet pet) async {
    await _wait();
    final index = _customers.indexWhere((item) => item.id == customerId);
    final customer = _customers[index];
    final pets = [...customer.pets];
    final petIndex = pets.indexWhere((item) => item.id == pet.id);
    if (petIndex < 0) {
      pets.add(pet);
    } else {
      pets[petIndex] = pet;
    }
    _customers[index] = Customer(
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
      email: customer.email,
      pets: pets,
      tutorUid: customer.tutorUid,
    );
    return _customers[index];
  }

  @override
  Future<PetService> saveService(
    PetService service, {
    PetService? original,
  }) async {
    await _wait();
    final index = _services.indexWhere((item) => item.id == service.id);
    if (index < 0) {
      _services.add(service);
    } else {
      _services[index] = service;
    }
    return service;
  }

  @override
  Future<Professional> saveProfessional(Professional professional) async {
    await _wait();
    final index = _professionals.indexWhere(
      (item) => item.id == professional.id,
    );
    if (index < 0) {
      _professionals.add(professional);
    } else {
      _professionals[index] = professional;
    }
    return professional;
  }

  @override
  Future<ScheduleBlock> saveBlock(ScheduleBlock block) async {
    await _wait();
    // Same id replaces the block, as on the server.
    _blocks
      ..removeWhere((item) => item.id == block.id)
      ..add(block);
    return block;
  }

  @override
  Future<void> removeBlock(String id) async {
    await _wait();
    _blocks.removeWhere((item) => item.id == id);
  }

  @override
  Future<Appointment> updateAppointmentNotes(String id, String notes) async {
    await _wait();
    final index = _appointments.indexWhere((item) => item.id == id);
    _appointments[index] = _appointments[index].copyWith(notes: notes);
    return _appointments[index];
  }

  @override
  Future<Appointment> saveAppointment(Appointment appointment) async {
    await _wait();
    final index = _appointments.indexWhere((item) => item.id == appointment.id);
    if (index < 0) {
      _appointments.add(appointment);
    } else {
      _appointments[index] = appointment;
    }
    return appointment;
  }

  @override
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status,
  ) async {
    await _wait();
    final index = _appointments.indexWhere((item) => item.id == id);
    _appointments[index] = _appointments[index].copyWith(status: status);
    return _appointments[index];
  }
}
