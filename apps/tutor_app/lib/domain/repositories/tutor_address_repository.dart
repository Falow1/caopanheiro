/// Address of the tutor for the transport: the street with the number, the
/// district and the city, and the point on the map that the route uses.
class TutorAddress {
  const TutorAddress({
    required this.street,
    required this.district,
    required this.lat,
    required this.lng,
  });

  /// "Rua das Acácias, 245, Cuiabá".
  final String street;

  /// "Centro, Cuiabá · apto 12".
  final String district;
  final double lat;
  final double lng;

  Map<String, dynamic> get point => {'lat': lat, 'lng': lng};
  Map<String, dynamic> toJson() => {
    'street': street,
    'district': district,
    'point': point,
  };

  /// "Rua das Acácias, 245, Cuiabá · Centro, Cuiabá".
  String get label => district.isEmpty ? street : '$street · $district';

  static TutorAddress? fromJson(Object? value) {
    if (value is! Map) return null;
    final point = value['point'];
    if (point is! Map) return null;
    final lat = point['lat'], lng = point['lng'];
    if (lat is! num || lng is! num) return null;
    return TutorAddress(
      street: value['street'] as String? ?? '',
      district: value['district'] as String? ?? '',
      lat: lat.toDouble(),
      lng: lng.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TutorAddress &&
      other.street == street &&
      other.district == district &&
      other.lat == lat &&
      other.lng == lng;
  @override
  int get hashCode => Object.hash(street, district, lat, lng);
}

/// Street and district found for a point of the map; empty parts stay for
/// the tutor to write.
class ReversedAddress {
  const ReversedAddress({required this.street, required this.district});
  final String street;
  final String district;
}

/// The address kept in the account (users/{uid}), like the name and the
/// phone: it comes back filled in the transport of any petshop. Kept apart
/// from the other contracts so repositories without it keep working.
abstract interface class TutorAddressRepository {
  TutorAddress? get savedAddress;

  /// Saves the address, or removes it when null.
  Future<TutorAddress?> saveAddress(TutorAddress? address);

  /// Street and district of a point, from the map service of the petshop
  /// server; null when it knows no street there.
  Future<ReversedAddress?> reverseAddress(double lat, double lng);
}
