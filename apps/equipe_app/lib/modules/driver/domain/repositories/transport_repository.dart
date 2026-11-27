import '../models.dart';

/// Server side of the live position (backend/src/driver_location.js).
abstract interface class DriverLocationReporter {
  Future<void> reportLocation(
    String tenantId, {
    required double latitude,
    required double longitude,
    double? accuracy,
  });
}

abstract interface class TransportRepository {
  Future<DriverProfile> signIn(String login, String password);
  Future<List<TenantMembership>> getMemberships();
  Future<List<TransportJob>> getAssignedTransports();
  Future<TransportJob> checkPets(
    String id,
    String phase,
    List<TransportPetCheck> checks,
  );
  Future<TransportJob> transition(
    String transportId,
    TransportStatus expectedStatus,
    TransportStatus newStatus,
  );
  Future<TransportJob> addIncident(
    String transportId,
    String type,
    String description,
  );
}
