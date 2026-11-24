/// Only the registered species determines the pet icon. Unknown stays neutral.
String petEmojiForSpecies(String? species) =>
    switch (species?.trim().toLowerCase()) {
      'gato' => '🐈',
      'cachorro' => '🐕',
      _ => '🐾',
    };
