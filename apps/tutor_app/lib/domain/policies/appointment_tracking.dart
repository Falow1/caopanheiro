import '../models/appointment.dart';

List<Appointment> activeAppointments(List<Appointment> appointments) =>
    appointments
        .where(
          (a) =>
              a.status == AppointmentStatus.inProgress ||
              a.status == AppointmentStatus.petReceived,
        )
        .toList();

List<Appointment> upcomingAppointments(List<Appointment> appointments) =>
    appointments
        .where(
          (a) =>
              a.status == AppointmentStatus.confirmed ||
              a.status == AppointmentStatus.requested,
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

List<Appointment> appointmentHistory(List<Appointment> appointments) =>
    appointments
        .where(
          (appointment) => const [
            AppointmentStatus.completed,
            AppointmentStatus.cancelled,
            AppointmentStatus.noShow,
          ].contains(appointment.status),
        )
        .toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

bool canCancelAppointment(AppointmentStatus status) =>
    status == AppointmentStatus.confirmed ||
    status == AppointmentStatus.requested;
