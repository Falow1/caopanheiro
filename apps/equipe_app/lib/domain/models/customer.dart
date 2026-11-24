import 'pet.dart';

class Customer {
  const Customer({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.phone,
    required this.email,
    required this.pets,
    this.tutorUid,
  });
  final int? recordNumber;
  final String id;
  final String name;
  final String phone;
  final String email;
  final List<Pet> pets;
  final String? tutorUid;
}
