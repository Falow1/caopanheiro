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

  /// Invite pasted by the person. Chat apps do not turn `caopanheiro://`
  /// into a tappable link, so the person copies it, often with the whole
  /// message around it or a final period; the link is found in the text.
  static StaffLink? fromText(String? text) {
    final link = tryParse(text);
    if (link != null) return link;
    final found = RegExp(r'caopanheiro://convite\?\S+').firstMatch(text ?? '');
    if (found == null) return null;
    return tryParse(found[0]!.replaceFirst(RegExp(r'[.,;:!?)\]}>"]+$'), ''));
  }

  /// Invite carried by a route name. On a cold start the route is the whole
  /// link; when the link arrives with the app already open, Flutter keeps
  /// only the path and the query, so `caopanheiro://convite?...` comes as
  /// `/?empresa=...`. Android only delivers convite links to the app.
  static StaffLink? fromRoute(String? name) {
    final link = tryParse(name);
    if (link != null) return link;
    final uri = Uri.tryParse(name?.trim() ?? '');
    if (uri == null || uri.hasScheme || uri.path != '/') return null;
    return tryParse(
      Uri(
        scheme: 'caopanheiro',
        host: 'convite',
        queryParameters: uri.queryParameters,
      ).toString(),
    );
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
