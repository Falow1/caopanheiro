class PetInternalNote {
  const PetInternalNote({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.authorName,
  });

  factory PetInternalNote.fromJson(Object? json) {
    final value = json as Map;
    return PetInternalNote(
      id: value['id'] as String,
      text: value['text'] as String,
      createdAt: DateTime.parse(value['createdAt'] as String).toLocal(),
      authorName: value['authorName'] as String? ?? '',
    );
  }

  final String id;
  final String text;
  final DateTime createdAt;
  final String authorName;
}
