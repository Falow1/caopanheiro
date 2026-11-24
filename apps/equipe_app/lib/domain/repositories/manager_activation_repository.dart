class ActivationCompany {
  const ActivationCompany({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.state,
  });
  final String id;
  final String name;
  final String phone;
  final String city;
  final String state;
}

class ManagerActivation {
  const ManagerActivation({
    required this.email,
    required this.emailVerified,
    required this.name,
    required this.phone,
    required this.companies,
  });
  final String email;
  final bool emailVerified;
  final String name;
  final String phone;
  final List<ActivationCompany> companies;
}

abstract interface class ManagerActivationRepository {
  Future<void> requestManagerPassword(String email);
  Future<ManagerActivation> beginManagerActivation(
    String email,
    String password,
  );
  Future<void> sendManagerVerification();
  Future<void> completeManagerActivation({
    required String tenantId,
    required String name,
    required String phone,
    required String companyPhone,
    required String city,
    required String state,
  });
}

// Auth succeeded, but there is no operational session for this new invitation.
class ManagerActivationRequired implements Exception {
  const ManagerActivationRequired(this.profile);
  final ManagerActivation profile;
}
