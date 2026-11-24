abstract interface class TeamLoginRepository {
  Future<bool> hasManagerInvitation(String email);
  Future<void> resendManagerInvitation(String email);
}

class TeamLoginException extends FormatException {
  TeamLoginException(super.message, this.retryAfterMs);
  final int retryAfterMs;
}
