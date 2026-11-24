import '../models.dart';

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
