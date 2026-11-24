class Professional {
  const Professional({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
  });

  final int? recordNumber;
  final String id;
  final String name;
  final String role;
  final String email;
  final String phone;
}
