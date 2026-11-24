class SuperAdmin {
  const SuperAdmin({
    required this.name,
    required this.email,
    this.role = 'Superadmin',
  });
  final String name;
  final String email;
  final String role;
}
