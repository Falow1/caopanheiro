import 'scheduling_policy.dart';

class Professional {
  const Professional({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.specialty,
    this.active = true,
    this.email = '',
    this.availability,
  });
  final int? recordNumber;
  final String id;
  final String name;
  final String specialty;
  final bool active;
  final String email;
  final Map<int, List<WorkPeriod>>? availability;
}
