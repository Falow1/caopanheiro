import 'appointment_status.dart';

/// Per-pet service progress. Older records inherit only the known group status.
class PetExecution {
  const PetExecution({
    required this.status,
    this.startedAt,
    this.completedAt,
    this.startedBy,
    this.completedBy,
    this.history = const [],
    this.legacyInherited = false,
  });
  final AppointmentStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? startedBy;
  final String? completedBy;
  final List<Map<String, dynamic>> history;
  final bool legacyInherited;

  factory PetExecution.fromJson(Object? raw, AppointmentStatus fallback) {
    if (raw == null)
      return PetExecution(status: fallback, legacyInherited: true);
    final value = Map<String, dynamic>.from(raw as Map);
    return PetExecution(
      status: AppointmentStatus.fromApi(value['status'] as String),
      startedAt: DateTime.tryParse(value['startedAt'] as String? ?? ''),
      completedAt: DateTime.tryParse(value['completedAt'] as String? ?? ''),
      startedBy: value['startedBy'] as String?,
      completedBy: value['completedBy'] as String?,
      history: ((value['history'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      legacyInherited: value['legacyInherited'] == true,
    );
  }
  Map<String, dynamic> toJson() => {
    'status': status.apiValue,
    'history': history,
    if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
    if (startedBy != null) 'startedBy': startedBy,
    if (completedBy != null) 'completedBy': completedBy,
    if (legacyInherited) 'legacyInherited': true,
  };
}
