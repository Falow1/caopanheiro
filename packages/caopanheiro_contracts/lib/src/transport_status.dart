enum TransportType {
  pickup('PICKUP', 'Coleta'),
  returnTrip('RETURN', 'Retorno');

  const TransportType(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum TransportStatus {
  assigned('ASSIGNED', 'Atribuído'),
  goingToOrigin('GOING_TO_ORIGIN', 'A caminho'),
  petCollected('PET_COLLECTED', 'Pet coletado'),
  inTransit('IN_TRANSIT', 'Em transporte'),
  delivered('DELIVERED', 'Entregue'),
  cancelled('CANCELLED', 'Cancelado');

  const TransportStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;
  bool get finished => this == delivered || this == cancelled;

  static TransportStatus fromApi(String value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () =>
        throw FormatException('Status de transporte inválido: $value'),
  );
}
