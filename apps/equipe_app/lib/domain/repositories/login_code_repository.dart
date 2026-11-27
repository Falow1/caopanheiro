/// Second step of the login: a code of six numbers sent by e-mail.
abstract interface class LoginCodeRepository {
  /// Creates a code and returns the challenge to verify.
  Future<String> requestLoginCode();
  Future<void> verifyLoginCode(String challengeId, String code);
}
