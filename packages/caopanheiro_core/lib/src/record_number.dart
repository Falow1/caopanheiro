/// Server-assigned, positive integer; absent in older offline snapshots.
int? readRecordNumber(Object? value) =>
    value is num &&
        value.isFinite &&
        value > 0 &&
        value <= 9007199254740991 &&
        value == value.toInt()
    ? value.toInt()
    : null;

/// Presentation only: never allocates or authorizes a number on the client.
String recordNumberLabel(int? value) => value == null ? '—' : value.toString();

String recordHeading(String title, int? number) =>
    number == null ? title : '$title · nº ${recordNumberLabel(number)}';

String recordCaption(String original, String type, int? number) =>
    number == null
    ? original
    : '$type nº ${recordNumberLabel(number)} · $original';

bool recordNumberMatches(int? number, String query) =>
    number != null && int.tryParse(query.trim()) == number;
