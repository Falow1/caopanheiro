enum TenantRole {
  manager('MANAGER', 'Gestor'),
  attendant('ATTENDANT', 'Atendente'),
  professional('PROFESSIONAL', 'Profissional'),
  driver('DRIVER', 'Entregador');

  const TenantRole(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static TenantRole fromApi(String value) => values.firstWhere(
    (role) => role.apiValue == value,
    orElse: () => throw FormatException('Papel inválido: $value'),
  );
}
