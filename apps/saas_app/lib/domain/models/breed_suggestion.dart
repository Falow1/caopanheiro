/// Breed typed in "Outra raça" by tutors and teams, grouped by name and
/// species. Only the name, the species and how many times: no pet, tutor or
/// petshop comes with it.
class BreedSuggestion {
  const BreedSuggestion({
    required this.id,
    required this.name,
    required this.species,
    required this.count,
    this.lastAt,
  });
  final String id;
  final String name;
  final String species;
  final int count;
  final DateTime? lastAt;
}
