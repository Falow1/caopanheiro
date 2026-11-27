import 'package:caopanheiro_core/caopanheiro_core.dart'
    show displayPhone, recordNumberLabel;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppButtonStyles,
        AppContentCard,
        AppRadii,
        AppTextStyles,
        showAppConfirmation;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../audit/audit_screen.dart';
import '../metrics/tenant_metrics_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../subscriptions/subscription_detail_screen.dart';
import '../users/tenant_users_screen.dart';
import 'tenant_form_screen.dart';

class TenantDetailScreen extends StatelessWidget {
  const TenantDetailScreen({super.key, required this.tenantId});
  final String tenantId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final tenant = controller.tenantById(tenantId);
    final plan = controller.planById(tenant.planId);
    return Scaffold(
      appBar: AppBar(title: Text(tenantIdentification(tenant))),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContextHeader(tenant: tenant, planName: plan.name),
            const SizedBox(height: 22),
            AppContentCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _Info(label: 'Razão social', value: tenant.name),
                  _Info(
                    label: 'Código da empresa',
                    value: recordNumberLabel(tenant.recordNumber),
                  ),
                  _Info(label: 'Responsável', value: tenant.responsible),
                  _Info(
                    label: 'Contato',
                    value: '${tenant.email}\n${displayPhone(tenant.phone)}',
                  ),
                  _Info(
                    label: 'Localização',
                    value: '${tenant.city} · ${tenant.state}',
                  ),
                  _Info(
                    label: 'Criada em',
                    value: date(tenant.createdAt),
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionTitle('Visão administrativa'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.75,
              children: [
                _Count(label: 'Usuários', value: '${tenant.users.length}'),
                _Count(
                  label: 'Profissionais',
                  value: tenant.metrics.available
                      ? '${tenant.metrics.professionals}'
                      : '—',
                ),
                _Count(label: 'Serviços', value: '${tenant.metrics.services}'),
                _Count(
                  label: 'Agendamentos/mês',
                  value: tenant.metrics.available
                      ? '${tenant.metrics.monthlyAppointments}'
                      : '—',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle('Gerenciar empresa'),
            _Action(
              icon: Icons.edit_outlined,
              label: 'Editar empresa',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TenantFormScreen(tenantId: tenant.id),
                ),
              ),
            ),
            _Action(
              icon: Icons.group_outlined,
              label: 'Ver usuários',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TenantUsersScreen(tenantId: tenant.id),
                ),
              ),
            ),
            _Action(
              icon: Icons.checklist_rounded,
              label: 'Ver onboarding',
              subtitle:
                  '${tenant.onboardingDone}/${tenant.onboarding.length} concluído',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(tenantId: tenant.id),
                ),
              ),
            ),
            _Action(
              icon: Icons.credit_card_outlined,
              label: 'Ver assinatura',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubscriptionDetailScreen(tenantId: tenant.id),
                ),
              ),
            ),
            _Action(
              icon: Icons.insights_outlined,
              label: 'Ver métricas',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TenantMetricsScreen(tenantId: tenant.id),
                ),
              ),
            ),
            _Action(
              icon: Icons.history_rounded,
              label: 'Ver histórico',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AuditScreen(tenantId: tenant.id),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (tenant.status != TenantStatus.active)
              FilledButton.icon(
                onPressed: controller.busy
                    ? null
                    : () => _reactivate(context, controller, tenant),
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(
                  tenant.status == TenantStatus.suspended
                      ? 'Reativar empresa'
                      : 'Liberar empresa',
                ),
              )
            else
              OutlinedButton.icon(
                style: AppButtonStyles.dangerOutlinedPlatform,
                onPressed: controller.busy
                    ? null
                    : () => _suspend(context, controller, tenant),
                icon: const Icon(Icons.pause_circle_outline_rounded),
                label: const Text('Suspender empresa'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _suspend(
    BuildContext context,
    AppController controller,
    Tenant tenant,
  ) async {
    var reason = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Suspender ${tenantIdentification(tenant)}?'),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Usuários desta empresa perderão acesso às operações até a reativação. A assinatura continuará com a situação atual e os dados não serão excluídos.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                onChanged: (value) => reason = value,
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Informe um motivo com pelo menos três caracteres'
                    : null,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo da suspensão',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: AppButtonStyles.dangerFilled,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Suspender empresa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.setTenantStatus(
        tenant.id,
        TenantStatus.suspended,
        reason.trim(),
      );
    }
  }

  Future<void> _reactivate(
    BuildContext context,
    AppController controller,
    Tenant tenant,
  ) async {
    final confirmed = await showAppConfirmation(
      context,
      title: 'Reativar ${tenantIdentification(tenant)}?',
      message:
          'A suspensão administrativa será removida. O uso continuará bloqueado se a assinatura não estiver ativa ou em trial válido.',
      confirmLabel: 'Reativar empresa',
    );
    if (confirmed) {
      await controller.setTenantStatus(tenant.id, TenantStatus.active);
    }
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value, this.last = false});
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 105, child: Text(label, style: AppTextStyles.metadata)),
        Expanded(child: Text(value, style: AppTextStyles.value)),
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => AppContentCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: AppRadii.r12,
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(label, style: AppTextStyles.strong),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    ),
  );
}
