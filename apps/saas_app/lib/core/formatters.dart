import 'package:caopanheiro_core/caopanheiro_core.dart' show recordHeading;
import '../domain/models/tenant.dart';

String tenantIdentification(Tenant tenant) =>
    recordHeading(tenant.tradeName, tenant.recordNumber);

String money(num value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
String date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String dateTime(DateTime value) => '${date(value)} ${time(value)}';
