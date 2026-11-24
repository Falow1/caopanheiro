class Plan {
  const Plan({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.maxProfessionals,
    required this.maxUsers,
    required this.features,
    this.active = true,
  });
  final int? recordNumber;
  final String id;
  final String name;
  final String description;
  final double monthlyPrice;
  final int maxProfessionals;
  final int maxUsers;
  final List<String> features;
  final bool active;
  Plan copyWith({
    String? name,
    String? description,
    double? monthlyPrice,
    int? maxProfessionals,
    int? maxUsers,
    List<String>? features,
    bool? active,
  }) => Plan(
    id: id,
    recordNumber: recordNumber,
    name: name ?? this.name,
    description: description ?? this.description,
    monthlyPrice: monthlyPrice ?? this.monthlyPrice,
    maxProfessionals: maxProfessionals ?? this.maxProfessionals,
    maxUsers: maxUsers ?? this.maxUsers,
    features: features ?? this.features,
    active: active ?? this.active,
  );
}
