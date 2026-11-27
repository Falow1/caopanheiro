import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetPolicy;

/// Pets the petshop serves (Mais → Funcionamento → Pets atendidos) and
/// "Não atender este pet". Both need a connection and stay apart from the
/// customer record: nothing here changes the pet data.
abstract interface class PetServiceRepository {
  Future<PetPolicy> getPetPolicy();

  /// [tenantId] saves the same rule in another petshop of the same manager.
  Future<PetPolicy> savePetPolicy(PetPolicy policy, {String? tenantId});

  /// Returns how many appointments still to happen the pet keeps booked.
  Future<int> blockPet(String customerId, String petId, String reason);
  Future<void> unblockPet(String customerId, String petId);
}
