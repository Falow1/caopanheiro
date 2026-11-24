const _months = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];
const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

String formatMoney(num value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

/// Distance of [meters] in kilometres, with a comma, as the money.
String formatKm(num meters) =>
    '${(meters / 1000).toStringAsFixed(2).replaceAll('.', ',')} km';
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String formatShortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]}';
String formatWeekday(DateTime date) => _weekdays[date.weekday - 1];
String formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String formatDateTime(DateTime date) =>
    '${formatDate(date)} às ${formatTime(date)}';
