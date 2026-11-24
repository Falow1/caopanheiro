enum AppointmentStatus {
  requested('REQUESTED', 'Solicitado'),
  confirmed('CONFIRMED', 'Confirmado'),
  petReceived('PET_RECEIVED', 'Pet recebido'),
  inProgress('IN_PROGRESS', 'Em atendimento'),
  completed('COMPLETED', 'Finalizado'),
  cancelled('CANCELLED', 'Cancelado'),
  noShow('NO_SHOW', 'Não compareceu');

  const AppointmentStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static AppointmentStatus fromApi(String value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () =>
        throw FormatException('Status de agendamento inválido: $value'),
  );
}
