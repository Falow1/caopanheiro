import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import 'application/onboarding_operations.dart';
import 'manager_form_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final tenant = controller.tenantById(tenantId);
    final plan = controller.planById(tenant.planId);
    final progress = onboardingProgress(tenant);

    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContextHeader(tenant: tenant, planName: plan.name),
            const SizedBox(height: 24),
            Text(
              'Onboarding ${tenant.onboardingDone}/${tenant.onboarding.length} concluído',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: AppRadii.r99,
            ),
            const SizedBox(height: 24),
            ...tenant.onboarding.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: step.completed
                          ? AppColors.mint
                          : AppColors.onboardingPendingSurface,
                      child: Icon(
                        step.completed
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        color: step.completed
                            ? AppColors.primary
                            : AppColors.orange,
                      ),
                    ),
                    title: Text(step.label, style: AppTextStyles.strong),
                    subtitle: Text(
                      !step.verified
                          ? 'Atualize online para verificar'
                          : step.completed
                          ? 'Concluído'
                          : 'Pendente',
                    ),
                  ),
                ),
              ),
            ),
            if (needsInitialManager(tenant)) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManagerFormScreen(tenantId: tenant.id),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Criar Gestor'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
