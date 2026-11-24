import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppRadii;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';

class TenantMetricsScreen extends StatelessWidget {
  const TenantMetricsScreen({super.key, required this.tenantId});
  final String tenantId;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final tenant = controller.tenantById(tenantId);
    final metrics = tenant.metrics;
    if (!metrics.available) {
      return Scaffold(
        appBar: AppBar(title: const Text('Métricas da empresa')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Esta cópia anterior não contém métricas. Atualize a consulta online para obtê-las.',
            ),
          ),
        ),
      );
    }
    final values = [
      ('Profissionais ativos', metrics.professionals, Icons.badge_outlined),
      ('Serviços ativos', metrics.services, Icons.content_cut_outlined),
      ('Cadastros de tutores', metrics.tutors, Icons.people_outline_rounded),
      ('Pets', metrics.pets, Icons.pets_outlined),
      (
        'Agendamentos no mês',
        metrics.monthlyAppointments,
        Icons.calendar_month_outlined,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Métricas da empresa')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContextHeader(
              tenant: tenant,
              planName: controller.planById(tenant.planId).name,
            ),
            const SizedBox(height: 24),
            const Text(
              'Dados agregados de utilização, sem informações pessoais de clientes finais.',
            ),
            const SizedBox(height: 20),
            ...values.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppContentCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: AppRadii.r13,
                        ),
                        child: Icon(item.$3, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.$1,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${item.$2}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
