const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
const _shortMonths = [
  'JAN',
  'FEV',
  'MAR',
  'ABR',
  'MAI',
  'JUN',
  'JUL',
  'AGO',
  'SET',
  'OUT',
  'NOV',
  'DEZ',
];
const _weekdays = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

String time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String fullDate(DateTime value) =>
    '${value.day} de ${_months[value.month - 1]}';
String date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String dateHeader(DateTime value) =>
    '${_weekdays[value.weekday - 1]}, ${value.day} ${_shortMonths[value.month - 1]}';

/// Greeting for the hour of [value]: morning from 5:00, afternoon from 12:00
/// and evening from 18:00.
String greeting(DateTime value) => value.hour >= 5 && value.hour < 12
    ? 'Bom dia'
    : value.hour >= 12 && value.hour < 18
    ? 'Boa tarde'
    : 'Boa noite';
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
