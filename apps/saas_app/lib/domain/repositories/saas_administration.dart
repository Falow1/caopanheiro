import '../models.dart';

abstract interface class SaasAdministration {
  bool get requiresEmailCode;
  bool get authenticated;
  Future<String> requestEmailCode();
  Future<SuperAdmin> verifyEmailCode(String code);
  Future<void> changePassword(String currentPassword, String password);
  Future<PlatformHealth> health();
  Future<SupportDiagnostic> diagnose(String tenantId, String reason);
}

abstract interface class SaasDemoAdministration {
  bool get canSkipEmailCode;
  Future<SuperAdmin> skipDemoEmailCode();
}
