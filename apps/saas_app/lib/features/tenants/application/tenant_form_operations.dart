import 'package:caopanheiro_core/caopanheiro_core.dart';
import '../../../domain/models.dart';

Tenant createTenantFromForm({
  required Tenant? original,
  String? newId,
  required String name,
  required String tradeName,
  required String slug,
  required String document,
  required String phone,
  required String email,
  required String city,
  required String state,
  required TenantStatus status,
  required String? planId,
}) => Tenant(
  id: original?.id ?? newId ?? newRecordId(),
  name: name.trim(),
  tradeName: tradeName.trim(),
  slug: slug.trim(),
  document: document.trim(),
  phone: phone.trim(),
  email: email.trim(),
  city: city.trim(),
  state: state.trim().toUpperCase(),
  status: status,
  planId: planId!,
  createdAt: original?.createdAt ?? DateTime.now(),
  responsible: original?.responsible ?? 'Não definido',
  users: original?.users ?? const [],
  metrics:
      original?.metrics ??
      const TenantMetrics(
        professionals: 0,
        services: 0,
        tutors: 0,
        pets: 0,
        monthlyAppointments: 0,
      ),
  onboarding:
      original?.onboarding ??
      const [
        OnboardingStep('Empresa criada', true),
        OnboardingStep('Gestor cadastrado', false),
        OnboardingStep('Horário de funcionamento configurado', false),
        OnboardingStep('Serviço cadastrado', false),
        OnboardingStep('Profissional cadastrado', false),
        OnboardingStep('Pronto para receber agendamentos', false),
      ],
);
