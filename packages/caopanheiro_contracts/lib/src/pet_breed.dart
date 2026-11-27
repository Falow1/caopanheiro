part 'pet_breed_catalog.dart';

/// BREED: a breed. SRD: no defined breed. OTHER: a breed that is not on the
/// list. SRD and OTHER exist for each dog size, so the size comes from the list.
enum PetBreedKind { breed, srd, other }

/// Entry of the breed list. The server (backend/src/pet_breeds.js) is the
/// source; this copy lets the apps search, show the size and the icon before
/// sending. The code is stored in the pet and never changes.
final class PetBreed {
  const PetBreed(
    this.code,
    this.name,
    this.species,
    this.size,
    this.kind,
    this.icon,
    this.aliases,
  );

  final String code;
  final String name;
  final String species;
  final String size;
  final PetBreedKind kind;

  /// Name of the icon in the visual package (assets/pet_breeds/{icon}.webp).
  final String icon;
  final List<String> aliases;

  @override
  String toString() => name;
}

List<PetBreed> _parseCatalog(String data) => [
  for (final line in data.split('\n'))
    if (line.trim().isNotEmpty) _parseBreed(line.trim()),
];

PetBreed _parseBreed(String line) {
  final fields = line.split('|');
  return PetBreed(
    fields[0],
    fields[1],
    fields[2],
    fields[3],
    switch (fields[4]) {
      'SRD' => PetBreedKind.srd,
      'OTHER' => PetBreedKind.other,
      _ => PetBreedKind.breed,
    },
    fields[5],
    fields.length > 6 && fields[6].isNotEmpty
        ? List.unmodifiable(fields[6].split(';'))
        : const [],
  );
}

abstract final class PetBreeds {
  static final List<PetBreed> all = List.unmodifiable(
    _parseCatalog(_catalogData),
  );
  static const sizes = ['Pequeno', 'Médio', 'Grande'];
  static final Map<String, PetBreed> _byCode = {
    for (final breed in all) breed.code: breed,
  };
  static final Map<String, Set<String>> _keys = {
    for (final breed in all)
      breed.code: {
        for (final term in [breed.name, ...breed.aliases]) _compact(term),
      },
  };

  static PetBreed? byCode(String? code) => code == null ? null : _byCode[code];

  static List<PetBreed> ofSpecies(String species) =>
      all.where((breed) => breed.species == species).toList(growable: false);

  /// "Outra raça" of the species, in the size of the pet (dogs).
  static PetBreed other(String species, String? size) => species == 'Gato'
      ? _byCode['gato-outra']!
      : _byCode['outra-${switch (size) {
          'Pequeno' => 'pequeno',
          'Grande' => 'grande',
          _ => 'medio',
        }}']!;

  /// No defined breed, in the size of the pet (dogs).
  static PetBreed srd(String species, String? size) => species == 'Gato'
      ? _byCode['gato-srd']!
      : _byCode['srd-${switch (size) {
          'Pequeno' => 'pequeno',
          'Grande' => 'grande',
          _ => 'medio',
        }}']!;

  /// Breed of a copy of the pet saved before the list (old appointments and
  /// transports), by its text, as the server converts old pets.
  static PetBreed? legacy(String species, String? breed, String? size) {
    final key = _compact(breed ?? '');
    if (key.isEmpty) return null;
    final found = all.where(
      (entry) => entry.species == species && _keys[entry.code]!.contains(key),
    );
    if (found.isEmpty) return null;
    return found.where((entry) => entry.size == size).firstOrNull ??
        found.first;
  }

  /// Breed of a pet as received: by its code or, for older copies, its text.
  static PetBreed? of({
    String? breedCode,
    required String species,
    String? breed,
    String? size,
  }) {
    final saved = byCode(breedCode);
    if (saved != null && saved.species == species) return saved;
    return legacy(species, breed, size);
  }
}

const _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
  'ý': 'y',
  'ÿ': 'y',
};
final _separators = RegExp('[^a-z0-9]+');

/// Lower case, no accents and only letters and digits separated by one space,
/// as the server compares breed names.
String normalizeBreedText(String value) {
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().replaceAll(_separators, ' ').trim();
}

String _compact(String value) => normalizeBreedText(value).replaceAll(' ', '');

/// One result of the breed search. [approximate] marks a name found by
/// similarity ("Você quis dizer…?"), not by what was typed.
final class PetBreedMatch {
  const PetBreedMatch(this.breed, this.score, {this.approximate = false});
  final PetBreed breed;
  final int score;
  final bool approximate;
}

/// Searches [breeds] by name and other names, ignoring accents and case and
/// accepting small typing mistakes. Without a query every breed is listed,
/// "sem raça definida" first.
List<PetBreedMatch> searchPetBreeds(
  String query,
  Iterable<PetBreed> breeds, {
  int limit = 40,
}) {
  final typed = normalizeBreedText(query);
  int kindOrder(PetBreed breed) => switch (breed.kind) {
    PetBreedKind.srd => 0,
    PetBreedKind.breed => 1,
    PetBreedKind.other => 2,
  };
  if (typed.isEmpty) {
    final sorted = breeds.toList()
      ..sort((a, b) {
        final kind = kindOrder(a).compareTo(kindOrder(b));
        return kind != 0 ? kind : _compareNames(a, b);
      });
    return [for (final breed in sorted.take(limit)) PetBreedMatch(breed, 0)];
  }
  final matches = <PetBreedMatch>[];
  for (final breed in breeds) {
    var best = 0;
    var approximate = false;
    for (final term in [breed.name, ...breed.aliases]) {
      final (score, fuzzy) = _score(typed, normalizeBreedText(term));
      if (score > best) {
        best = score;
        approximate = fuzzy;
      }
    }
    if (best > 0) {
      matches.add(PetBreedMatch(breed, best, approximate: approximate));
    }
  }
  matches.sort((a, b) {
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    final kind = kindOrder(a.breed).compareTo(kindOrder(b.breed));
    return kind != 0 ? kind : _compareNames(a.breed, b.breed);
  });
  // An exact or partial match hides guesses by similarity.
  final direct = matches.where((match) => !match.approximate).toList();
  return (direct.isNotEmpty ? direct : matches).take(limit).toList();
}

int _compareNames(PetBreed a, PetBreed b) =>
    normalizeBreedText(a.name).compareTo(normalizeBreedText(b.name));

(int, bool) _score(String typed, String term) {
  if (term == typed) return (100, false);
  if (term.startsWith(typed)) return (90, false);
  final words = term.split(' ');
  if (words.any((word) => word.startsWith(typed))) return (80, false);
  final compactTyped = typed.replaceAll(' ', '');
  final compactTerm = term.replaceAll(' ', '');
  if (compactTyped.length >= 3 && compactTerm.contains(compactTyped)) {
    return (70, false);
  }
  if (compactTyped.length < 3) return (0, false);
  final allowed = compactTyped.length <= 4
      ? 1
      : compactTyped.length <= 8
      ? 2
      : 3;
  var distance = allowed + 1;
  for (final candidate in {compactTerm, ...words}) {
    final prefix = candidate.length > compactTyped.length + 1
        ? candidate.substring(0, compactTyped.length)
        : candidate;
    final value = _distance(compactTyped, prefix);
    if (value < distance) distance = value;
  }
  return distance <= allowed ? (60 - distance * 10, true) : (0, false);
}

/// Edit distance with swapped neighbours counting as one change.
int _distance(String a, String b) {
  final rows = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    rows[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    rows[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var value = [
        rows[i - 1][j] + 1,
        rows[i][j - 1] + 1,
        rows[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        final swap = rows[i - 2][j - 2] + 1;
        if (swap < value) value = swap;
      }
      rows[i][j] = value;
    }
  }
  return rows[a.length][b.length];
}
