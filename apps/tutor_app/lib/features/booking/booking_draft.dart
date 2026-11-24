import 'package:caopanheiro_core/caopanheiro_core.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/service.dart';

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
  String? professionalId;
  String? professionalName;
  DateTime? companyStartsAt;
  final List<Pet> pets;
  final Map<String, Set<PetService>> selectedServices;
  DateTime? startsAt;
  Map<String, dynamic>? transportQuote;
  String tutorNotes = '';

  Iterable<PetService> get allServices =>
      selectedServices.values.expand((items) => items);
  double get totalPrice =>
      allServices.fold(0, (sum, service) => sum + service.price);
  int get totalDuration =>
      allServices.fold(0, (sum, service) => sum + service.durationMinutes);
  int get totalServices => allServices.length;
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
