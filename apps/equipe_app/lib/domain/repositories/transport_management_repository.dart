class CompanyDriver {
  const CompanyDriver(this.id, this.name);
  final String id;
  final String name;
}

/// Company wall clock sent to the server, which reads it in the company zone
/// (its own city), whatever the zone of this device.
String companyClockLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'
    'T${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class TransportRequest {
  const TransportRequest({
    required this.id,
    required this.appointmentId,
    required this.driverUid,
    required this.type,
    required this.scheduledAt,
    required this.origin,
    required this.destination,
    required this.notes,
    this.estimatedDurationMinutes,
    this.conflictAcknowledgement,
  });
  final String id;
  final String appointmentId;
  final String driverUid;
  final String type;

  /// Chosen on the company wall clock.
  final DateTime scheduledAt;
  final Map<String, String> origin;
  final Map<String, String> destination;
  final String notes;
  final int? estimatedDurationMinutes;
  final String? conflictAcknowledgement;
}

abstract interface class TransportManagementRepository {
  Future<List<CompanyDriver>> getDrivers();
  Future<void> createTransport(TransportRequest request);
  Future<List<ManagedTransport>> getTransports({String? appointmentId});
  /// With [appointmentId], [at] is a company wall clock read in the zone of
  /// that appointment; otherwise it is the instant of an existing transport.
  Future<TransportConflictPreview> conflicts(
    String driverUid,
    DateTime at,
    int? duration, {
    String? excludeId,
    String? appointmentId,
  });
  Future<void> reassign(
    ManagedTransport transport,
    String driverUid,
    String reason,
    bool custodyConfirmed,
    String acknowledgement,
  );
  Future<void> manageIncident(
    String transportId,
    String incidentId,
    String status,
    String message,
  );
}

class ManagedIncident {
  const ManagedIncident(
    this.id,
    this.type,
    this.description,
    this.status,
    this.response,
    this.resolution,
  );
  final String id, type, description, status, response, resolution;
}

class ManagedTransport {
  const ManagedTransport({
    required this.id,
    this.recordNumber,
    this.appointmentNumber,
    required this.appointmentId,
    required this.driverUid,
    required this.type,
    required this.status,
    required this.scheduledAt,
    this.companyScheduledAt,
    required this.incidents,
    required this.history,
    required this.checks,
    this.estimatedDurationMinutes,
  });
  final int? recordNumber;
  final int? appointmentNumber;
  final String id, appointmentId, driverUid, type, status;
  final DateTime scheduledAt;

  /// Wall clock of the company, as sent by the server.
  final DateTime? companyScheduledAt;
  DateTime get displayScheduledAt => companyScheduledAt ?? scheduledAt;
  final int? estimatedDurationMinutes;
  final List<ManagedIncident> incidents;
  final List<String> history, checks;
  bool get finished => status == 'CANCELLED' || status == 'DELIVERED';
  bool get inCustody => status == 'PET_COLLECTED' || status == 'IN_TRANSIT';
}

class TransportConflictPreview {
  const TransportConflictPreview(
    this.messages,
    this.acknowledgement,
    this.incomplete,
  );
  final List<String> messages;
  final String acknowledgement;
  final bool incomplete;
}
