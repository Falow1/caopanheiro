class StaffLink {
  const StaffLink({
    required this.tenantId,
    required this.inviteId,
    required this.token,
  });
  final String tenantId, inviteId, token;
  Map<String, dynamic> get data => {
    'tenantId': tenantId,
    'inviteId': inviteId,
    'token': token,
  };
  String get url => Uri(
    scheme: 'caopanheiro',
    host: 'convite',
    queryParameters: {'empresa': tenantId, 'id': inviteId, 'chave': token},
  ).toString();
  static StaffLink? tryParse(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null) return null;
    if (!(uri.scheme == 'caopanheiro' && uri.host == 'convite' ||
        uri.scheme.isEmpty && uri.path == '/convite')) {
      return null;
    }
    final tenant = uri.queryParameters['empresa'],
        id = uri.queryParameters['id'],
        token = uri.queryParameters['chave'];
    if (tenant == null ||
        id == null ||
        token == null ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(tenant) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(id) ||
        !RegExp(r'^[a-f0-9]{32,64}$').hasMatch(token)) {
      return null;
    }
    return StaffLink(tenantId: tenant, inviteId: id, token: token);
  }
}

abstract interface class StaffLinkRepository {
  bool get invitationEmailVerified;
  Future<String> createStaffLink(Map<String, dynamic> input);
  Future<void> unlinkWorkforceMember(Map<String, dynamic> input);
  Future<Map<String, dynamic>> inspectStaffLink(StaffLink link);
  Future<void> authenticateStaffLink(
    StaffLink link, {
    required String email,
    required String password,
    required bool createAccount,
  });
  Future<void> sendLinkVerification();
  Future<void> acceptStaffLink(
    StaffLink link, {
    required String name,
    required String phone,
    String? specialty,
  });
}
