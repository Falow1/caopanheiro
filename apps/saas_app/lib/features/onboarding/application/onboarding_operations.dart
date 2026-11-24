import 'package:caopanheiro_core/caopanheiro_core.dart';
import '../../../domain/models.dart';

TenantUser createInitialManager({
  required String name,
  required String email,
}) => TenantUser(
  id: newRecordId(),
  name: name.trim(),
  email: email.trim(),
  role: TenantRole.manager,
  createdAt: DateTime.now(),
);

double onboardingProgress(Tenant tenant) =>
    tenant.onboardingDone / tenant.onboarding.length;

bool needsInitialManager(Tenant tenant) => !tenant.onboarding[1].completed;
