class TenantMetrics {
  const TenantMetrics({
    this.available = true,
    required this.professionals,
    required this.services,
    required this.tutors,
    required this.pets,
    required this.monthlyAppointments,
  });
  final bool available;
  final int professionals;
  final int services;
  final int tutors;
  final int pets;
  final int monthlyAppointments;
}
