import '../../../domain/models.dart';
import '../booking_draft.dart';

Appointment createAppointmentFromDraft(BookingDraft draft) => Appointment(
  id: draft.appointmentId,
  professionalId: draft.professionalId,
  professional: draft.professionalName,
  customer: draft.customer,
  companyStartsAt: draft.companyStartsAt,
  notes: draft.notes,
  startsAt: draft.startsAt!,
  status: AppointmentStatus.confirmed,
  items: draft.pets
      .map(
        (pet) => AppointmentItem(
          pet: pet,
          services: draft.services[pet.id]!.toList(),
        ),
      )
      .toList(),
);
