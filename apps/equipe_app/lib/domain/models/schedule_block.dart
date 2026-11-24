class ScheduleBlock {
  const ScheduleBlock({
    required this.id,
    this.recordNumber,
    required this.date,
    required this.start,
    required this.end,
    required this.reason,
    this.fullDay = false,
    this.canEdit = false,
    this.editableUntil,
  });
  final int? recordNumber;
  final String id;
  final DateTime date;
  final String start;
  final String end;
  final String reason;
  final bool fullDay;
  final bool canEdit;
  final DateTime? editableUntil;
  bool get canEditNow =>
      canEdit &&
      (editableUntil == null || editableUntil!.isAfter(DateTime.now()));
}
