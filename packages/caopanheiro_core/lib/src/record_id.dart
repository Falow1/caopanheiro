import 'dart:math';

/// Identificador opaco de 128 bits, criado uma vez por novo cadastro.
/// Não contém nome, papel, ambiente ou horário do dispositivo.
String newRecordId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
