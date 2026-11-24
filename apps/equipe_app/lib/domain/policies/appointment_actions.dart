import '../models.dart';

enum AppointmentActions { confirmed, startService, finishService, none }

AppointmentActions appointmentActionsFor(
  AppointmentStatus status,
  InternalUser? user,
) {
  if (status == AppointmentStatus.confirmed) {
    return AppointmentActions.confirmed;
  } else if (status == AppointmentStatus.petReceived &&
      (user?.canRunService ?? false)) {
    return AppointmentActions.startService;
  } else if (status == AppointmentStatus.inProgress &&
      (user?.canRunService ?? false)) {
    return AppointmentActions.finishService;
  }
  return AppointmentActions.none;
}
