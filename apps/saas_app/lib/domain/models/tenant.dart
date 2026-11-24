import 'onboarding_step.dart';
import 'tenant_metrics.dart';
import 'tenant_status.dart';
import 'tenant_user.dart';

class Tenant {
  const Tenant({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.tradeName,
    required this.slug,
    required this.document,
    required this.phone,
    required this.email,
    required this.city,
    required this.state,
    required this.status,
    required this.planId,
    required this.createdAt,
    required this.responsible,
    required this.users,
    required this.metrics,
    required this.onboarding,
  });
  final int? recordNumber;
  final String id;
  final String name;
  final String tradeName;
  final String slug;
  final String document;
  final String phone;
  final String email;
  final String city;
  final String state;
  final TenantStatus status;
  final String planId;
  final DateTime createdAt;
  final String responsible;
  final List<TenantUser> users;
  final TenantMetrics metrics;
  final List<OnboardingStep> onboarding;
  int get onboardingDone => onboarding.where((item) => item.completed).length;
  Tenant copyWith({
    String? name,
    String? tradeName,
    String? slug,
    String? document,
    String? phone,
    String? email,
    String? city,
    String? state,
    TenantStatus? status,
    String? planId,
    String? responsible,
    List<TenantUser>? users,
    List<OnboardingStep>? onboarding,
  }) => Tenant(
    id: id,
    recordNumber: recordNumber,
    name: name ?? this.name,
    tradeName: tradeName ?? this.tradeName,
    slug: slug ?? this.slug,
    document: document ?? this.document,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    city: city ?? this.city,
    state: state ?? this.state,
    status: status ?? this.status,
    planId: planId ?? this.planId,
    createdAt: createdAt,
    responsible: responsible ?? this.responsible,
    users: users ?? this.users,
    metrics: metrics,
    onboarding: onboarding ?? this.onboarding,
  );
}
