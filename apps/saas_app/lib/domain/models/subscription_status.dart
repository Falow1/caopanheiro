enum SubscriptionStatus {
  active('Ativa'),
  trial('Trial'),
  pending('Pendente'),
  expired('Vencida'),
  cancelled('Cancelada');

  const SubscriptionStatus(this.label);
  final String label;
}
