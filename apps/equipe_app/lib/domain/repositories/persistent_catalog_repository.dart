import 'internal_repository.dart';
import '../models/team_company.dart';

/// Authentication remains with the provider; SQLite never stores credentials.
abstract interface class AuthenticatedCatalogRepository
    implements InternalRepository {
  String? get currentUid;
}

abstract interface class PersistentCatalogRepository
    implements InternalRepository {
  Future<bool> restoreSession();
  bool get offline;
  bool get accessInvalidated;
  DateTime? get catalogUpdatedAt;
  DateTime? get customersUpdatedAt;
  DateTime? get agendaUpdatedAt;
  List<TeamCompany> get authorizedCompanies;
  String? get localWarning;
}

/// Metadata only, separate from authorizedCompanies and selection.
abstract interface class ManagementCompanyDirectory {
  List<ManagementCompany> get managementCompanies;
}
