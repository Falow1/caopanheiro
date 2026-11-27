/// Each person of the team edits their own name and phone. The e-mail is the
/// login and stays as it is.
abstract interface class OwnTeamProfileRepository {
  Future<void> updateOwnProfile(String name, String phone);
}
