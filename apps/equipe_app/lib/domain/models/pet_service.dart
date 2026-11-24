class PetService {
  const PetService({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.description,
    required this.duration,
    required this.price,
    this.active = true,
  });
  final int? recordNumber;
  final String id;
  final String name;
  final String description;
  final int duration;
  final double price;
  final bool active;
  PetService copyWith({
    String? name,
    String? description,
    int? duration,
    double? price,
    bool? active,
  }) => PetService(
    id: id,
    recordNumber: recordNumber,
    name: name ?? this.name,
    description: description ?? this.description,
    duration: duration ?? this.duration,
    price: price ?? this.price,
    active: active ?? this.active,
  );
}
