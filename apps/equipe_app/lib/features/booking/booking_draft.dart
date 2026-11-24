import 'package:caopanheiro_core/caopanheiro_core.dart';
import '../../domain/models.dart';

class BookingDraft {
  BookingDraft({
    required this.customer,
    String? appointmentId,
    this.editing = false,
  }) : appointmentId = appointmentId ?? newRecordId();
  final bool editing;
  final Customer customer;
  final String appointmentId;
  String notes = '';
  String? professionalId;
  String? professionalName;
  final List<Pet> pets = [];
  final Map<String, Set<PetService>> services = {};
  DateTime? startsAt;
  DateTime? companyStartsAt;
  DateTime get displayStartsAt => companyStartsAt ?? startsAt!;
  Iterable<PetService> get allServices =>
      services.values.expand((items) => items);
  int get duration => allServices.fold(0, (sum, item) => sum + item.duration);
  double get price => allServices.fold(0, (sum, item) => sum + item.price);
  bool get validServices =>
      pets.every((pet) => services[pet.id]?.isNotEmpty ?? false);
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
          duration: value['durationMinutes'] as int,
        );
      }).toSet();
    }
    for (final pet in pets) {
      final previous = services[pet.id]!.map((service) => service.id).toSet();
      final next = replacement[pet.id]?.map((service) => service.id).toSet();
      if (next == null ||
          next.length != previous.length ||
          !previous.containsAll(next)) {
        throw const FormatException(
          'Os serviços mudaram. Reinicie o agendamento.',
        );
      }
    }
    services.addAll(replacement);
  }
}
