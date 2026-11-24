enum TenantStatus {
  active('Ativo'),
  onboarding('Em onboarding'),
  suspended('Suspenso');

  const TenantStatus(this.label);
  final String label;
}
