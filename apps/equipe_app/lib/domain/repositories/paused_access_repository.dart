import '../models/team_company.dart';

/// Access paused (E2): the account has no petshop open for operation, only
/// petshops the principal manager still opens for the plan, Support and the
/// export. Raised by the sign-in instead of a company list.
class AccessPausedRequired implements Exception {
  const AccessPausedRequired(this.companies);
  final List<PausedCompany> companies;
}

/// Reads and commands of a paused petshop, without selecting it for
/// operation. The server accepts only the principal manager, and only the
/// plan, Support and the export.
abstract interface class PausedAccessRepository {
  List<PausedCompany> get pausedCompanies;

  Future<Map<String, dynamic>> pausedQuery(
    String tenantId,
    String name, [
    Map<String, dynamic> input = const {},
  ]);

  Future<Map<String, dynamic>> pausedCommand(
    String tenantId,
    String name,
    Map<String, dynamic> input,
  );
}
