import '../../core/formatters.dart';

import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppRadii, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import 'application/dashboard_queries.dart';
import '../../state/app_scope.dart';
import '../tenants/tenant_detail_screen.dart';
import '../tenants/tenant_form_screen.dart';
import '../subscriptions/billing_requests_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSelectTab});
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final admin = controller.admin;
    // The outgoing route can rebuild after signOut clears the session.
    if (admin == null) return const SizedBox.shrink();
    final (
      :active,
      :trial,
      :suspended,
      :users,
      :appointments,
      :recent,
      :attention,
    ) = dashboardSummary(
      controller.tenants,
      controller.subscriptions,
    );
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SaasPageTitle('Visão da plataforma'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Brand(compact: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Olá,',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        Text(
                          admin.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => onSelectTab(4),
                    icon: const Icon(Icons.person_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const PendingBoard(),

              const SizedBox(height: 16),
              Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Metric(
                            label: 'Empresas ativas',
                            value: '$active',
                            icon: Icons.storefront_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Metric(
                            label: 'Assinaturas trial',
                            value: '$trial',
                            icon: Icons.science_outlined,
                            color: AppColors.violet,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Metric(
                            label: 'Usuários internos',
                            value: '$users',
                            icon: Icons.groups_outlined,
                            color: AppColors.orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Metric(
                            label: 'Agendamentos/mês',
                            value:
                                controller.tenants.every(
                                  (t) => t.metrics.available,
                                )
                                ? '$appointments'
                                : 'Não disponível',
                            icon: Icons.calendar_month_outlined,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onSelectTab(1),
                      child: const Text('Ver empresas'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TenantFormScreen(),
                        ),
                      ),
                      child: const Text('Nova empresa'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SectionTitle(
                'Empresas recentes',
                action: 'Ver todas',
                onAction: () => onSelectTab(1),
              ),
              ...recent
                  .take(3)
                  .map(
                    (tenant) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Card(
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TenantDetailScreen(tenantId: tenant.id),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.mint,
                            child: Icon(
                              Icons.storefront_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            tenantIdentification(tenant),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            controller.planById(tenant.planId).name,
                          ),
                          trailing: TenantBadge(status: tenant.status),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
              if (attention.isNotEmpty) ...[
                const SectionTitle('Atenção necessária'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.noticeSurface,
                    borderRadius: AppRadii.r18,
                  ),
                  child: Column(
                    children: [
                      ...attention.map(
                        (tenant) => Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warning,
                            ),
                            title: Text(tenantIdentification(tenant)),
                            subtitle: Text(
                              tenant.status == TenantStatus.suspended
                                  ? 'Empresa suspensa'
                                  : 'Onboarding incompleto',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TenantDetailScreen(tenantId: tenant.id),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                '$suspended empresa(s) suspensa(s)',
                style: AppTextStyles.metadata,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 100),
    child: AppContentCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: value == 'Não disponível'
                      ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )
                      : Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    ),
  );
}
