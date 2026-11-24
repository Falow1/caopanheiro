enum AppFailureKind { validation, conflict, network, unexpected }

class AppFailure {
  const AppFailure({
    required this.kind,
    required this.message,
    this.code,
    this.networkProblem,
  });

  final AppFailureKind kind;
  final String message;
  final String? code;

  /// Why the server gave no answer, when [kind] is network.
  final NetworkProblem? networkProblem;
}

/// What the device could confirm about a call that got no answer.
enum NetworkProblem {
  noInternet(
    'Sem internet',
    'Sem internet. Confira o Wi-Fi ou os dados móveis e tente de novo.',
  ),
  serverUnreachable(
    'Servidor fora do ar',
    'Não foi possível se conectar ao servidor. Tente de novo em alguns minutos.',
  ),
  timeout(
    'Servidor sem resposta',
    'O servidor não confirmou a tempo. Atualize para conferir ou repita com os mesmos dados.',
  ),
  serverError(
    'Falha no servidor',
    'O servidor não conseguiu concluir agora. Tente de novo em alguns minutos.',
  );

  const NetworkProblem(this.title, this.message);

  /// Short name for banners, e.g. "Sem internet".
  final String title;

  /// Full sentence for the screen where the operation failed.
  final String message;

  /// Banner of the read-only mode, e.g. "Sem internet · somente consulta".
  String get readOnlyBanner => '$title · somente consulta';
}

/// Keeps the reason of its latest call without answer, for the banners.
abstract interface class NetworkProblemSource {
  NetworkProblem? get lastNetworkProblem;
}

/// A call without answer from the server. Explicit commands keep their
/// pending request on this failure, so the same data can be sent again.
class NetworkException implements Exception {
  const NetworkException([
    String? message,
    this.problem = NetworkProblem.serverUnreachable,
  ]) : _message = message;

  const NetworkException.of(this.problem) : _message = null;

  final String? _message;
  final NetworkProblem problem;
  String get message => _message ?? problem.message;

  @override
  String toString() => message;
}

class ServiceQuoteChangedException extends FormatException {
  ServiceQuoteChangedException(this.quote)
    : super(
        'Os valores ou a duração dos serviços mudaram. Revise o resumo e confirme novamente.',
      );
  final Map<String, dynamic> quote;
}
