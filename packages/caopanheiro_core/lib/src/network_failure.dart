import 'app_failure.dart';
import 'local_firebase_gateway.dart' show SessionAccessException;

/// Firebase codes that may mean the server gave no answer, with the reason
/// assumed until the device confirms it. Other codes are answers.
NetworkProblem? networkFallbackFor(String code) => switch (code) {
  'network-request-failed' => NetworkProblem.serverUnreachable,
  'deadline-exceeded' => NetworkProblem.timeout,
  'internal' ||
  'unknown' ||
  'unavailable' ||
  'cancelled' => NetworkProblem.serverError,
  _ => null,
};

/// The device checks its network and the server now: no internet or server
/// down replace [fallback]; a server that answers keeps it.
Future<NetworkException> confirmNetworkProblem(
  NetworkProblem fallback,
  Future<NetworkProblem?> Function() probe, [
  String? message,
]) async {
  NetworkProblem? seen;
  try {
    seen = await probe();
  } catch (_) {
    // A failed check confirms nothing; the assumed reason stays.
  }
  return NetworkException(message, seen ?? fallback);
}

/// Google sign-in and linking failures as messages. An unknown code may be a
/// device without internet: on Android the provider page reports a failed
/// lookup of the Google address as an internal error, not as
/// network-request-failed. [probe] checks the connection before Google is
/// blamed; a failed check confirms nothing.
Future<Exception> googleFailure(
  String code,
  Future<NetworkProblem?> Function() probe,
) async {
  switch (code) {
    case 'account-exists-with-different-credential' || 'email-already-in-use':
      return const FormatException(
        'Já existe uma conta com este e-mail. Entre com e-mail e senha e vincule o Google no Perfil.',
      );
    case 'credential-already-in-use':
      return const FormatException(
        'Esta conta Google já está ligada a outro acesso.',
      );
    case 'provider-already-linked':
      return const FormatException('O Google já está vinculado a esta conta.');
    case 'popup-closed-by-user' ||
        'cancelled-popup-request' ||
        'web-context-canceled' ||
        'web-context-cancelled' ||
        'canceled':
      return const FormatException('Entrada com Google cancelada.');
    case 'popup-blocked':
      return const FormatException(
        'O navegador bloqueou a janela do Google. Permita pop-ups e tente de novo.',
      );
  }
  NetworkProblem? problem;
  try {
    problem = await probe();
  } catch (_) {}
  return problem == null
      ? const SessionAccessException(
          'Não foi possível entrar com o Google. Tente novamente.',
        )
      : NetworkException.of(problem);
}

/// Firebase Auth refusals as messages the person can act on. [signingIn]
/// tells wrong credentials apart from a session that ended during use.
FormatException authFailure(String code, {required bool signingIn}) {
  switch (code) {
    case 'too-many-requests':
      return const FormatException(
        'Muitas tentativas seguidas. Aguarde alguns minutos e tente de novo.',
      );
    case 'user-disabled':
      return const SessionAccessException('Esta conta está desativada.');
    case 'email-already-in-use':
      return const FormatException(
        'Este e-mail já tem uma conta. Entre com ele ou use outro e-mail.',
      );
    case 'weak-password':
      return const FormatException(
        'Senha fraca. Escolha uma senha mais longa.',
      );
    case 'invalid-email':
      return const FormatException('E-mail inválido.');
    case 'requires-recent-login':
      return const SessionAccessException(
        'Por segurança, entre novamente para continuar.',
      );
    case 'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials':
    case 'user-not-found' when signingIn:
      return const SessionAccessException('E-mail ou senha incorretos.');
    case 'user-not-found' || 'user-token-expired' || 'invalid-user-token':
      return const SessionAccessException(
        'Sua sessão terminou ou a conta foi excluída. Entre novamente.',
      );
  }
  return const SessionAccessException(
    'Não foi possível autenticar esta conta. Confira o e-mail, a senha e a situação do acesso.',
  );
}

/// Server contract these apps speak, declared in every call. Raise it with
/// the server minimum (`backend/src/callable.js`) only when older apps can no
/// longer talk to the server.
const int clientProtocol = 1;

/// [data] plus the declared contract; [data] itself is not changed.
Map<String, dynamic> withClientProtocol(Map<String, dynamic> data) => {
  ...data,
  'clientProtocol': clientProtocol,
};

/// The server refused this app version as too old.
bool isAppOutdated(String code, Object? details) =>
    code == 'failed-precondition' &&
    details is Map &&
    details['reason'] == 'APP_OUTDATED';

/// This app version is no longer accepted; only an update solves it.
class AppOutdatedException extends FormatException {
  const AppOutdatedException()
    : super(
        'Esta versão do aplicativo não é mais aceita. Atualize o aplicativo para continuar.',
      );
}
