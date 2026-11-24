import 'package:caopanheiro_core/caopanheiro_core.dart' show recordCaption;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../state/app_scope.dart';
import 'plan_form_screen.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Planos')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
        itemCount: controller.plans.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final plan = controller.plans[index];
          return Card(
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlanFormScreen(planId: plan.id),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 10,
              ),
              title: Text(
                plan.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                recordCaption(
                  '${money(plan.monthlyPrice)}/mês · Até ${plan.maxProfessionals} profissionais',
                  'Plano',
                  plan.recordNumber,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: plan.active
                      ? AppColors.mint
                      : AppColors.inactiveSurface,
                  borderRadius: AppRadii.r99,
                ),
                child: Text(
                  plan.active ? 'Ativo' : 'Inativo',
                  style: TextStyle(
                    color: plan.active ? AppColors.primary : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlanFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo plano'),
      ),
    );
  }
}
