class StaffActivation {
  const StaffActivation({
    required this.email,
    required this.emailVerified,
    required this.name,
    required this.phone,
    required this.companies,
  });
  final String email, name, phone;
  final bool emailVerified;
  final List<Map<String, dynamic>> companies;
}

class StaffActivationRequired implements Exception {
  const StaffActivationRequired(this.profile);
  final StaffActivation profile;
}

abstract interface class StaffInvitationRepository {
  Future<void> inviteWorkforceUser(Map<String, dynamic> input);
  Future<void> revokeWorkforceInvitation(String userId);
  Future<void> sendStaffVerification();
  Future<void> completeStaffActivation({
    required String tenantId,
    required String name,
    required String phone,
  });
}
