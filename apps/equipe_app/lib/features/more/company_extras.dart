/// Read-only view of the plan contracted by the petshop. Changing plan or
/// subscription is an administrative action of the platform.
class CompanyPlanInfo {
  const CompanyPlanInfo({
    required this.planName,
    required this.description,
    required this.features,
    required this.subscriptionStatus,
    required this.usedUsers,
    required this.usedProfessionals,
    this.maxUsers,
    this.maxProfessionals,
    this.monthlyPriceCents,
    this.renewsAt,
  });

  factory CompanyPlanInfo.fromJson(Map<String, dynamic> value) {
    final plan = value['plan'] == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(value['plan'] as Map);
    final subscription = Map<String, dynamic>.from(
      (value['subscription'] as Map?) ?? const {},
    );
    final usage = Map<String, dynamic>.from(
      (value['usage'] as Map?) ?? const {},
    );
    return CompanyPlanInfo(
      planName: plan['name'] as String? ?? '',
      description: plan['description'] as String? ?? '',
      features: ((plan['features'] as List?) ?? const []).cast<String>(),
      maxUsers: (plan['maxUsers'] as num?)?.toInt(),
      maxProfessionals: (plan['maxProfessionals'] as num?)?.toInt(),
      monthlyPriceCents: (plan['monthlyPriceCents'] as num?)?.toInt(),
      subscriptionStatus: subscription['status'] as String? ?? '',
      renewsAt: DateTime.tryParse(
        subscription['renewsAt'] as String? ?? '',
      )?.toLocal(),
      usedUsers: (usage['users'] as num?)?.toInt() ?? 0,
      usedProfessionals: (usage['professionals'] as num?)?.toInt() ?? 0,
    );
  }

  final String planName;
  final String description;
  final List<String> features;
  final int? maxUsers;
  final int? maxProfessionals;
  final int? monthlyPriceCents;
  final String subscriptionStatus;
  final DateTime? renewsAt;
  final int usedUsers;
  final int usedProfessionals;

  bool get hasPlan => planName.isNotEmpty;
  String get statusLabel => switch (subscriptionStatus) {
    'ACTIVE' => 'Ativa',
    'TRIAL' => 'Período de teste',
    'PENDING' => 'Pendente',
    'EXPIRED' => 'Expirada',
    'CANCELLED' => 'Cancelada',
    _ => 'Não informada',
  };
}

class SupportTicketMessage {
  const SupportTicketMessage({
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

/// Request sent by a manager to the platform administration.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
    this.replies = const [],
  });

  factory SupportTicket.fromJson(Map<String, dynamic> value) {
    DateTime moment(Object? raw) =>
        DateTime.tryParse(raw as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return SupportTicket(
      id: value['id'] as String,
      subject: value['subject'] as String? ?? '',
      message: value['message'] as String? ?? '',
      status: value['status'] as String? ?? '',
      authorName: value['authorName'] as String? ?? '',
      createdAt: moment(value['createdAt']),
      updatedAt: moment(value['updatedAt'] ?? value['createdAt']),
      replies: ((value['replies'] as List?) ?? const []).map((raw) {
        final reply = Map<String, dynamic>.from(raw as Map);
        return SupportTicketMessage(
          fromPlatform: reply['from'] == 'PLATFORM',
          authorName: reply['authorName'] as String? ?? '',
          message: reply['message'] as String? ?? '',
          at: moment(reply['at']),
        );
      }).toList(),
    );
  }

  final String id;
  final String subject;
  final String message;

  /// OPEN (waiting for the platform), ANSWERED or CLOSED.
  final String status;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupportTicketMessage> replies;

  bool get closed => status == 'CLOSED';
  String get statusLabel => switch (status) {
    'OPEN' => 'Aguardando o suporte',
    'ANSWERED' => 'Respondido',
    'CLOSED' => 'Encerrado',
    _ => 'Situação não informada',
  };
}
