import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetExecution;
import 'package:caopanheiro_core/caopanheiro_core.dart' show readRecordNumber;
import '../domain/models.dart';
import '../domain/models/scheduling_policy.dart';

Map<String, dynamic> jsonMap(Object? value) =>
    Map<String, dynamic>.from(value as Map);
Pet petFromJson(Map<String, dynamic> value) => Pet(
  id: value['id'] as String,
  recordNumber: readRecordNumber(value['recordNumber']),
  name: value['name'] as String,
  species: value['species'] as String,
  breed: value['breed'] as String,
  size: value['size'] as String,
  birthDate: DateTime.parse(value['birthDate'] as String),
  notes: value['notes'] as String? ?? '',
);
Map<String, dynamic> petToJson(Pet value) => {
  'id': value.id,
  if (value.recordNumber != null) 'recordNumber': value.recordNumber,
  'name': value.name,
  'species': value.species,
  'breed': value.breed,
  'size': value.size,
  'birthDate':
      '${value.birthDate.year.toString().padLeft(4, '0')}-${value.birthDate.month.toString().padLeft(2, '0')}-${value.birthDate.day.toString().padLeft(2, '0')}',
  'notes': value.notes,
};
Customer customerFromJson(Map<String, dynamic> value) => Customer(
  id: value['id'] as String,
  recordNumber: readRecordNumber(value['recordNumber']),
  name: value['name'] as String,
  phone: value['phone'] as String,
  email: value['email'] as String,
  tutorUid: value['tutorUid'] as String?,
  pets: (value['pets'] as List? ?? [])
      .map((pet) => petFromJson(jsonMap(pet)))
      .toList(),
);
Map<String, dynamic> customerToJson(Customer value) => {
  'id': value.id,
  if (value.recordNumber != null) 'recordNumber': value.recordNumber,
  'name': value.name,
  'phone': value.phone,
  'email': value.email,
  'tutorUid': value.tutorUid,
  'pets': value.pets.map(petToJson).toList(),
};

String civilDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
PetService serviceFromJson(Map<String, dynamic> value) => PetService(
  id: value['id'] as String,
  recordNumber: readRecordNumber(value['recordNumber']),
  name: value['name'] as String,
  description: value['description'] as String? ?? '',
  duration: (value['durationMinutes'] as num).toInt(),
  price: (value['priceCents'] as num).toInt() / 100,
  active: value['active'] as bool? ?? true,
);
Map<String, dynamic> serviceToJson(PetService value) => {
  'id': value.id,
  if (value.recordNumber != null) 'recordNumber': value.recordNumber,
  'name': value.name,
  'description': value.description,
  'durationMinutes': value.duration,
  'priceCents': (value.price * 100).round(),
  'active': value.active,
};
Appointment appointmentFromJson(Map<String, dynamic> value) => Appointment(
  id: value['id'] as String,
  recordNumber: readRecordNumber(value['recordNumber']),
  customer: customerFromJson(jsonMap(value['customer'])),
  companyStartsAt: value['localStartsAt'] == null
      ? null
      : DateTime.parse(value['localStartsAt'] as String),
  startsAt: DateTime.parse(value['startsAt'] as String).toLocal(),
  status: AppointmentStatus.fromApi(value['status'] as String),
  professional: value['professional'] as String?,
  professionalId: value['professionalId'] as String?,
  notes: value['notes'] as String? ?? '',
  tutorNotes: value['tutorNotes'] as String? ?? '',
  observations: ((value['observations'] as List?) ?? const []).map((raw) {
    final note = jsonMap(raw);
    return ServiceNote(
      petId: note['petId'] as String? ?? '',
      text: note['text'] as String? ?? '',
      createdAt: DateTime.tryParse(note['createdAt'] as String? ?? ''),
    );
  }).toList(),
  items: (value['items'] as List).map((raw) {
    final item = jsonMap(raw);
    return AppointmentItem(
      pet: petFromJson(jsonMap(item['pet'])),
      execution: PetExecution.fromJson(
        item['execution'],
        AppointmentStatus.fromApi(value['status'] as String),
      ),
      services: (item['services'] as List)
          .map((service) => serviceFromJson(jsonMap(service)))
          .toList(),
    );
  }).toList(),
);
Map<String, dynamic> appointmentToJson(Appointment value) => {
  'id': value.id,
  if (value.recordNumber != null) 'recordNumber': value.recordNumber,
  'customer': customerToJson(value.customer),
  'startsAt': value.startsAt.toUtc().toIso8601String(),
  if (value.companyStartsAt != null)
    'localStartsAt': value.companyStartsAt!.toIso8601String(),
  'status': value.status.apiValue,
  'professional': value.professional,
  'professionalId': value.professionalId,
  'notes': value.notes,
  'tutorNotes': value.tutorNotes,
  'observations': value.observations
      .map(
        (note) => {
          'petId': note.petId,
          'text': note.text,
          if (note.createdAt != null)
            'createdAt': note.createdAt!.toUtc().toIso8601String(),
        },
      )
      .toList(),
  'items': value.items
      .map(
        (item) => {
          'pet': petToJson(item.pet),
          if (item.execution != null) 'execution': item.execution!.toJson(),
          'services': item.services.map(serviceToJson).toList(),
        },
      )
      .toList(),
};
Map<int, List<WorkPeriod>> periodsFromJson(Object? raw) {
  if (raw == null) return {};
  return jsonMap(raw).map(
    (key, value) => MapEntry(
      int.parse(key),
      (value as List).map((raw) {
        final period = jsonMap(raw);
        return WorkPeriod(
          period['start'] is num
              ? (period['start'] as num).toInt()
              : WorkPeriod.parse(period['start'] as String),
          period['end'] is num
              ? (period['end'] as num).toInt()
              : WorkPeriod.parse(period['end'] as String),
        );
      }).toList(),
    ),
  );
}

Map<String, dynamic> periodsToJson(Map<int, List<WorkPeriod>> days) => days.map(
  (day, periods) =>
      MapEntry('$day', periods.map((period) => period.toJson()).toList()),
);
Professional professionalFromJson(Map<String, dynamic> value) => Professional(
  id: value['id'] as String,
  recordNumber: readRecordNumber(value['recordNumber']),
  name: value['name'] as String,
  specialty: value['specialty'] as String? ?? '',
  email: value['email'] as String? ?? '',
  active: value['active'] as bool? ?? true,
  availability: value['availability'] == null
      ? null
      : periodsFromJson(value['availability']),
);
Map<String, dynamic> professionalToJson(Professional value) => {
  'id': value.id,
  if (value.recordNumber != null) 'recordNumber': value.recordNumber,
  'name': value.name,
  'specialty': value.specialty,
  'email': value.email,
  'active': value.active,
  if (value.availability != null)
    'availability': periodsToJson(value.availability!),
};
ScheduleBlock blockFromJson(Map<String, dynamic> value) => ScheduleBlock(
  id: value['id'] as String,
  recordNumber: readRecordNumber(value['recordNumber']),
  date: DateTime.parse(value['date'] as String),
  start: value['start'] as String,
  end: value['end'] as String,
  reason: value['reason'] as String,
  fullDay: value['fullDay'] as bool? ?? false,
  canEdit: value['canEdit'] as bool? ?? false,
  editableUntil: DateTime.tryParse(value['editableUntil'] as String? ?? ''),
);
Map<String, dynamic> blockToJson(ScheduleBlock value) => {
  'id': value.id,
  if (value.recordNumber != null) 'recordNumber': value.recordNumber,
  'date': civilDate(value.date),
  'start': value.start,
  'end': value.end,
  'reason': value.reason,
  'fullDay': value.fullDay,
  'canEdit': value.canEdit,
  if (value.editableUntil != null)
    'editableUntil': value.editableUntil!.toUtc().toIso8601String(),
};
SchedulingPolicy policyFromJson(Map<String, dynamic> value) => SchedulingPolicy(
  configured: value['configured'] as bool? ?? false,
  timeZone: value['timeZone'] as String? ?? 'America/Cuiaba',
  slotMinutes: (value['slotMinutes'] as num?)?.toInt() ?? 15,
  days: periodsFromJson(value['days']),
);
Map<String, dynamic> policyToJson(SchedulingPolicy value) => {
  'configured': value.configured,
  'timeZone': value.timeZone,
  'slotMinutes': value.slotMinutes,
  'days': periodsToJson(value.days),
};
