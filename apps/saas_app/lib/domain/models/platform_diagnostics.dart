import 'onboarding_step.dart';

class ServiceHealth {
  const ServiceHealth({required this.available, this.latencyMs});
  final bool available;
  final int? latencyMs;
}

class PlatformHealth {
  const PlatformHealth({
    required this.ready,
    required this.environment,
    required this.checkedAt,
    required this.services,
    this.version,
  });
  final bool ready;
  final String environment;
  final String? version;
  final DateTime checkedAt;
  final Map<String, ServiceHealth> services;
}

class SupportDiagnostic {
  const SupportDiagnostic({
    required this.tenantId,
    required this.tenantStatus,
    required this.checkedAt,
    required this.onboarding,
    this.subscriptionStatus,
  });
  final String tenantId;
  final String tenantStatus;
  final String? subscriptionStatus;
  final DateTime checkedAt;
  final List<OnboardingStep> onboarding;
}
