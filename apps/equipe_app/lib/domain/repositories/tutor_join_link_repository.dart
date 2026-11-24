/// A tutor who was unlinked by this petshop and opened its fixed link: the
/// principal manager approves or refuses the return. Name and e-mail are
/// read from the account when the list is loaded; the request keeps none.
class TutorReturnRequest {
  const TutorReturnRequest({
    required this.uid,
    required this.name,
    required this.email,
    this.customerName,
    this.requestedAt,
  });
  final String uid, name, email;
  final String? customerName;
  final DateTime? requestedAt;

  factory TutorReturnRequest.fromJson(Map<String, dynamic> json) =>
      TutorReturnRequest(
        uid: json['uid'] as String,
        name: (json['name'] as String?)?.trim() ?? '',
        email: json['email'] as String? ?? '',
        customerName: json['customerName'] as String?,
        requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? ''),
      );
}

/// The petshop's fixed invite link as the management sees it: the code
/// (`tenantId.token`), whether it is active and, for the principal manager
/// only ([canManage]), the pending return requests.
class TutorJoinLink {
  const TutorJoinLink({
    required this.tenantId,
    required this.code,
    required this.active,
    required this.canManage,
    this.requests = const [],
    this.moreRequests = false,
  });
  final String tenantId, code;
  final bool active, canManage, moreRequests;
  final List<TutorReturnRequest> requests;

  factory TutorJoinLink.fromJson(Map<String, dynamic> json) => TutorJoinLink(
    tenantId: json['tenantId'] as String,
    code: json['code'] as String,
    active: json['active'] == true,
    canManage: json['canManage'] == true,
    requests: [
      for (final row in json['requests'] as List? ?? const [])
        TutorReturnRequest.fromJson(Map<String, dynamic>.from(row as Map)),
    ],
    moreRequests: json['moreRequests'] == true,
  );
}

enum TutorJoinLinkAction { disable, enable, rotate }

/// Fixed invite link of the selected petshop. Reading creates the link the
/// first time; every action needs connection.
abstract interface class TutorJoinLinkRepository {
  Future<TutorJoinLink> getTutorJoinLink();
  Future<void> setTutorJoinLink(TutorJoinLinkAction action);
  Future<void> decideTutorReturn(String uid, {required bool approve});
}
