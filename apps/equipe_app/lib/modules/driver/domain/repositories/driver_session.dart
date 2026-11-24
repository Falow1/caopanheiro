import '../models.dart';

abstract interface class DriverSession {
  bool get readOnly;
  DateTime? get updatedAt;
  String? get cacheWarning;
  Future<DriverProfile?> restore();
  Future<void> signOut();
}

abstract interface class AttachedSession {
  bool get hasPendingCommands;
  Future<DriverProfile> attachCompany(String id);
  void detachView();
}
