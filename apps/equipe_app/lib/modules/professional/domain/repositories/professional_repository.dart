import '../models.dart';

abstract interface class ProfessionalRepository {
  Future<Professional> signIn(String identifier, String password);
  Future<List<Appointment>> getAppointments(String professionalId);
  Future<void> updateStatus(String appointmentId, AppointmentStatus status);
  Future<void> addObservation(
    String appointmentId,
    ServiceObservation observation,
  );
}
