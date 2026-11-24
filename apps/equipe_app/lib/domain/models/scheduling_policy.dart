class WorkPeriod {
  const WorkPeriod(this.start, this.end);
  final int start;
  final int end;
  static int parse(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) {
      throw const FormatException('Use HH:mm nos horários.');
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException('Horário inválido.');
    }
    return hour * 60 + minute;
  }

  static String label(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  Map<String, String> toJson() => {'start': label(start), 'end': label(end)};
}

class SchedulingPolicy {
  const SchedulingPolicy({
    required this.configured,
    required this.timeZone,
    required this.slotMinutes,
    required this.days,
  });
  final bool configured;
  final String timeZone;
  final int slotMinutes;
  final Map<int, List<WorkPeriod>> days;
  static const initial = SchedulingPolicy(
    configured: false,
    timeZone: 'America/Cuiaba',
    slotMinutes: 15,
    days: {},
  );
}

class AvailableSlot {
  const AvailableSlot({
    required this.startsAt,
    required this.label,
    required this.professionalId,
    required this.professionalName,
  });
  final DateTime startsAt;
  final String label;
  final String professionalId;
  final String professionalName;
}
