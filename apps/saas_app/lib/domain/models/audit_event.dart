class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.action,
    required this.admin,
    required this.createdAt,
    required this.entity,
    required this.result,
    this.tenantId,
    this.reason,
    this.details = const {},
    this.fromTenant = false,
  });

  /// True for a sensitive action performed inside a petshop by its own team,
  /// mirrored here; false for actions of the platform administration.
  final bool fromTenant;
  final String id;
  final String action;
  final String admin;
  final DateTime createdAt;
  final String entity;
  final String result;
  final String? tenantId;
  final String? reason;
  final Map<String, dynamic> details;
}
