import '../models.dart';
import '../models/team_company.dart';

abstract interface class InternalRepository {
  Future<InternalUser> signIn(String identifier, String password);
  Future<List<TeamCompany>> getCompanies();
  Future<InternalUser> selectCompany(String id);
  Future<void> signOut();
  Future<List<Customer>> getCustomers();
  Future<List<PetService>> getServices();
  Future<List<Appointment>> getAppointments();
  Future<List<Professional>> getProfessionals();
  Future<List<ScheduleBlock>> getBlocks();
  Future<Customer> saveCustomer(Customer customer);
  Future<Customer> savePet(String customerId, Pet pet);
  Future<PetService> saveService(PetService service, {PetService? original});
  Future<Professional> saveProfessional(Professional professional);
  Future<ScheduleBlock> saveBlock(ScheduleBlock block);
  Future<void> removeBlock(String id);
  Future<Appointment> saveAppointment(Appointment appointment);
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status,
  );
}
