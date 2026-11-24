import 'dart:convert';
import 'dart:io';

/// Test-only emulator administration. This helper must never enter app lib/.
Future<String> readLocalEmailCode(String challengeId) async {
  if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(challengeId)) {
    throw StateError('Identificador QA inválido.');
  }
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse(
        'http://10.0.2.2:8080/v1/projects/demo-caopanheiro-local/databases/(default)/documents/platformEmailOutbox/$challengeId',
      ),
    );
    request.headers.set('Authorization', 'Bearer owner');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw StateError('Mensagem local indisponível.');
    }
    final value = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
    final fields = value['fields'] as Map;
    final text = (fields['text'] as Map)['stringValue'] as String;
    return RegExp(r'\b\d{6}\b').firstMatch(text)!.group(0)!;
  } finally {
    client.close(force: true);
  }
}

Future<String> readLatestQaEmailCode(String uid) async {
  if (!RegExp(r'^qa32-native-[a-f0-9]+$').hasMatch(uid)) {
    throw StateError('Conta não pertence à fixture QA.');
  }
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse(
        'http://10.0.2.2:8080/v1/projects/demo-caopanheiro-local/databases/(default)/documents/platformEmailLimits/$uid',
      ),
    );
    request.headers.set('Authorization', 'Bearer owner');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw StateError('Verificação não iniciada.');
    }
    final value = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
    final id =
        ((value['fields'] as Map)['challengeId'] as Map)['stringValue']
            as String;
    return await readLocalEmailCode(id);
  } finally {
    client.close(force: true);
  }
}
