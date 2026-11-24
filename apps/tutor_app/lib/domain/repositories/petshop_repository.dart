import '../models/appointment.dart';
import '../models/pet.dart';
import '../models/service.dart';
import '../models/tutor.dart';

abstract interface class PetshopRepository {
  Future<Tutor> signIn(String identifier, String password);
  Future<Tutor> signUp(Tutor tutor, String password);
  Future<Tutor> updateTutor(Tutor tutor);
  Future<List<Pet>> getPets();
  Future<void> savePet(Pet pet);
  Future<List<PetService>> getServices();
  Future<List<Appointment>> getAppointments();
  Future<Appointment> createAppointment(Appointment appointment);
  Future<Appointment> cancelAppointment(String id);
}
