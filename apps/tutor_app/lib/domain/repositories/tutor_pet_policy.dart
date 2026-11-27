import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetPolicy;

/// Pets the selected petshop serves, read together with the customer record.
/// Kept apart from [PetshopRepository] so repositories without it keep
/// working: then every pet is served, as before the rule existed.
abstract interface class TutorPetPolicySource {
  PetPolicy get petPolicy;
}
