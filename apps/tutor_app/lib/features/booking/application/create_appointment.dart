import '../../../domain/models/appointment.dart';
import '../booking_draft.dart';

Appointment createAppointmentFromDraft(BookingDraft draft) => Appointment(
  id: draft.appointmentId,
  expectedServices: draft.pets
      .map(
        (pet) => {
          'petId': pet.id,
          'services': draft.selectedServices[pet.id]!
              .map(
                (service) => {
                  'id': service.id,
                  'priceCents': (service.price * 100).round(),
                  'durationMinutes': service.durationMinutes,
                },
              )
              .toList(),
        },
      )
      .toList(),
  transportQuoteId: draft.transportQuote?['id'] as String?,
  transport: draft.transportQuote,
  tutorNotes: draft.tutorNotes.trim(),
  companyId: draft.companyId,
  professionalId: draft.professionalId,
  companyStartsAt: draft.companyStartsAt,
  startsAt: draft.startsAt!,
  status: AppointmentStatus.confirmed,
  items: draft.pets.map((pet) {
    final services = draft.selectedServices[pet.id]!.toList();
    return AppointmentItem(
      petId: pet.id,
      petName: pet.name,
      serviceIds: services.map((service) => service.id).toList(),
      serviceNames: services.map((service) => service.name).toList(),
      price: services.fold(0, (sum, service) => sum + service.price),
      durationMinutes: services.fold(
        0,
        (sum, service) => sum + service.durationMinutes,
      ),
    );
  }).toList(),
  history: [
    StatusEvent(status: AppointmentStatus.confirmed, at: DateTime.now()),
  ],
);
