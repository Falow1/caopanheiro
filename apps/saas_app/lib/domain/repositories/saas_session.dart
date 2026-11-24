import '../models.dart';

abstract interface class SaasSession {
  bool get readOnly;
  DateTime? get updatedAt;
  String? get cacheWarning;
  Future<SuperAdmin?> restore();
  Future<void> signOut();
  Future<void> saveMember(
    String tenantId,
    String name,
    String email,
    String role,
  );
}
