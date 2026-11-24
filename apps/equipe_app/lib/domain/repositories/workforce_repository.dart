abstract interface class WorkforceRepository {
  bool get hasPendingCommands;
  Future<List<Map<String, dynamic>>> workforceMembers();
  Future<void> saveWorkforceRoles(Map<String, dynamic> input);
}
