/// An unstarted trip from an earlier local day needs the team's review.
/// This is a presentation alert, not a new transport status or an automatic
/// cancellation. Trips already underway keep their normal custody workflow.
bool transportNeedsReview(
  DateTime scheduledAt,
  String status, {
  DateTime? now,
}) {
  final local = scheduledAt.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  return status == 'ASSIGNED' &&
      DateTime(
        local.year,
        local.month,
        local.day,
      ).isBefore(DateTime(today.year, today.month, today.day));
}

DateTime? transportReviewTime(Object? value) {
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
    }
  }
  return null;
}
