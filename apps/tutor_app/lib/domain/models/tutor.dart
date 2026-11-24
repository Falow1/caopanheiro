class Tutor {
  const Tutor({
    required this.name,
    this.recordNumber,
    required this.phone,
    required this.email,
  });
  final int? recordNumber;
  final String name;
  final String phone;
  final String email;
  Tutor copyWith({String? name, String? phone, String? email}) => Tutor(
    recordNumber: recordNumber,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email ?? this.email,
  );
}
