import '../models.dart';

enum ServiceActions { startService, inProgress, none }

ServiceActions serviceActionsFor(AppointmentStatus status) {
  if (status == AppointmentStatus.petReceived) {
    return ServiceActions.startService;
  }
  if (status == AppointmentStatus.inProgress) {
    return ServiceActions.inProgress;
  }
  return ServiceActions.none;
}
