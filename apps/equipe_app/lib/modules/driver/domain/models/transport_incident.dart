class TransportIncident {
  const TransportIncident({
    this.id = '',
    this.status = 'OPEN',
    this.response = '',
    this.resolution = '',
    required this.type,
    required this.description,
    required this.createdAt,
    required this.driverName,
  });
  final String id;
  final String status;
  final String response;
  final String resolution;
  final String type;
  final String description;
  final DateTime createdAt;
  final String driverName;
}
