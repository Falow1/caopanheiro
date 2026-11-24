import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show TransportStatus;

class TransportEvent {
  const TransportEvent({
    required this.status,
    required this.createdAt,
    required this.actor,
  });
  final TransportStatus status;
  final DateTime createdAt;
  final String actor;
}
