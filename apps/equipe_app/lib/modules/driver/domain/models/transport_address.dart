class TransportAddress {
  const TransportAddress({
    required this.name,
    required this.street,
    required this.district,
    required this.phone,
    this.latitude,
    this.longitude,
  });
  final String name;
  final String street;
  final String district;
  final String phone;
  final double? latitude;
  final double? longitude;
  bool get hasPoint =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;
  String get fullAddress => '$street, $district';
  String get shortAddress => '$district · $name';
}
