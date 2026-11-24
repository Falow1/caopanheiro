class SupportMessage {
  const SupportMessage({
    required this.fromPlatform,
    required this.authorName,
    required this.message,
    required this.at,
  });
  final bool fromPlatform;
  final String authorName;
  final String message;
  final DateTime at;
}

/// Request sent by the manager of a petshop to the platform administration.
class SupportRequest {
  const SupportRequest({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.authorName,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.replies = const [],
  });
  final String id;
  final String tenantId;
  final String tenantName;
  final String authorName;
  final String subject;
  final String message;

  /// OPEN (waiting for the platform), ANSWERED or CLOSED.
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupportMessage> replies;

  bool get closed => status == 'CLOSED';
  bool get waiting => status == 'OPEN';
  String get statusLabel => switch (status) {
    'OPEN' => 'Aguardando resposta',
    'ANSWERED' => 'Respondido',
    'CLOSED' => 'Encerrado',
    _ => 'Situação não informada',
  };
}
