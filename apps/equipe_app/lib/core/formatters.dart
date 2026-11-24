const _weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
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
String money(num amount) =>
    'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';
String time(DateTime item) =>
    '${item.hour.toString().padLeft(2, '0')}:${item.minute.toString().padLeft(2, '0')}';
String date(DateTime item) =>
    '${item.day.toString().padLeft(2, '0')}/${item.month.toString().padLeft(2, '0')}/${item.year}';
String friendlyDate(DateTime item) =>
    '${_weekdays[item.weekday - 1]}, ${item.day} de ${_months[item.month - 1]}';
