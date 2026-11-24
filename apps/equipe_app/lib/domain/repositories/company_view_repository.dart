import '../models.dart';

class CompanyViewPage {
  const CompanyViewPage(this.items, this.nextCursor);
  final List<Map<String, dynamic>> items;
  final String? nextCursor;
}

/// Online reads keep their explicit origin and never replace a company cache.
abstract interface class CompanyViewRepository {
  Future<CompanyViewPage> companyView({
    required String tenantId,
    required TenantRole role,
    required String resource,
    String? cursor,
  });
}
