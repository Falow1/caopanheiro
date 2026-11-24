import '../models.dart';

abstract interface class PetExecutionRepository {
  Future<Appointment> updatePetStatus(
    String appointmentId,
    String petId,
    AppointmentStatus status,
  );
}
