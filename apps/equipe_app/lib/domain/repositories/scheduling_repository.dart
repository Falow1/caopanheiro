import '../models.dart';
import '../models/scheduling_policy.dart';

abstract interface class AppointmentNotesRepository {
  Future<Appointment> updateAppointmentNotes(String id, String notes);
}

abstract interface class SchedulingRepository {
  Future<List<AvailableSlot>> getAvailableSlots(
    String customerId,
    List<AppointmentItem> items,
    DateTime day, {
    String? appointmentId,
  });
  Future<SchedulingPolicy> getSchedulingPolicy();
  Future<SchedulingPolicy> saveSchedulingPolicy(SchedulingPolicy value);
}
