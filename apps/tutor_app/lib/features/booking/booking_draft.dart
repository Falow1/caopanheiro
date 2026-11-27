import 'package:caopanheiro_core/caopanheiro_core.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/service.dart';
import '../../domain/repositories/tutor_session.dart';

const maxTutorNotesLength = 500;

class BookingDraft {
  BookingDraft({
    required this.pets,
    this.companyId,
    Map<String, Set<PetService>>? selectedServices,
    String? rescheduleOf,
  }) : selectedServices =
           selectedServices ?? {for (final pet in pets) pet.id: <PetService>{}},
       reschedule = rescheduleOf != null,
       appointmentId = rescheduleOf ?? newRecordId();

  /// True when the draft moves an existing appointment instead of creating one.
  final bool reschedule;
  final String appointmentId;
  final String? companyId;

  /// One professional for every pet, when the tutor chose so; null otherwise.
  String? professionalId;
  String? professionalName;

  /// [Distribution.any]: the server gives the pets to the free professionals.
  /// [Distribution.specific]: [assignments] says who does each pet.
  String distribution = Distribution.any;
  Map<String, String> assignments = {};

  /// Who does each pet and when, as chosen or as the server proposed for
  /// the time; shown in the summary and the review.
  List<SlotAssignment> plan = const [];

  /// Real time of the booking, the busiest professional; null before the time.
  int? scheduleMinutes;
  DateTime? companyStartsAt;
  final List<Pet> pets;
  final Map<String, Set<PetService>> selectedServices;
  DateTime? startsAt;
  Map<String, dynamic>? transportQuote;
  String tutorNotes = '';

  /// The payment chosen in the review. Demonstration: it is not sent to the
  /// petshop and nothing is charged.
  String? paymentMethod;

  Iterable<PetService> get allServices =>
      selectedServices.values.expand((items) => items);
  double get totalPrice =>
      allServices.fold(0, (sum, service) => sum + service.price);
  int get totalDuration =>
      allServices.fold(0, (sum, service) => sum + service.durationMinutes);
  int get totalServices => allServices.length;

  /// Summed minutes of the services of one pet, done in a row.
  int petMinutes(String petId) => (selectedServices[petId] ?? const {}).fold(
    0,
    (sum, service) => sum + service.durationMinutes,
  );

  /// Line of the summary: "Qualquer profissional", the one chosen for all,
  /// or the names of the professionals per pet.
  String get professionalLabel {
    if (distribution == Distribution.any) return 'Qualquer profissional';
    final names = {for (final row in plan) row.professionalName};
    if (professionalName != null) return professionalName!;
    return names.isEmpty ? 'A escolher' : names.join(', ');
  }

  /// "Ana · 08:00–09:00" per pet, once the time is chosen.
  Map<String, String> get petProfessionals => {
    for (final row in plan)
      row.petId:
          '${row.professionalName} · ${_clock(row.startsAt)}–${_clock(row.endsAt)}',
  };

  /// Wall clock of the petshop: the instant moved by the same offset as the
  /// chosen start ([companyStartsAt] against [startsAt]).
  String _clock(DateTime value) {
    final start = startsAt, local = companyStartsAt;
    final shifted = start == null || local == null
        ? value.toLocal()
        : local.add(value.difference(start));
    return '${shifted.hour.toString().padLeft(2, '0')}:${shifted.minute.toString().padLeft(2, '0')}';
  }

  bool get eachPetHasService =>
      pets.every((pet) => selectedServices[pet.id]?.isNotEmpty ?? false);
  void applyServiceQuote(Map<String, dynamic> quote) {
    final replacement = <String, Set<PetService>>{};
    for (final raw in quote['items'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      replacement[item['petId'] as String] = (item['services'] as List).map((
        rawService,
      ) {
        final value = Map<String, dynamic>.from(rawService as Map);
        return PetService(
          id: value['id'] as String,
          recordNumber: readRecordNumber(value['recordNumber']),
          name: value['name'] as String,
          description: value['description'] as String? ?? '',
          price: (value['priceCents'] as num) / 100,
          durationMinutes: value['durationMinutes'] as int,
        );
      }).toSet();
    }
    for (final pet in pets) {
      final previous = selectedServices[pet.id]!
          .map((service) => service.id)
          .toSet();
      final next = replacement[pet.id]?.map((service) => service.id).toSet();
      if (next == null ||
          next.length != previous.length ||
          !previous.containsAll(next)) {
        throw const FormatException(
          'Os serviços mudaram. Reinicie o agendamento.',
        );
      }
    }
    selectedServices.addAll(replacement);
  }
}
