class PetService {
  const PetService({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
  });
  final int? recordNumber;
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;
}
