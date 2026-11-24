import 'package:caopanheiro_core/caopanheiro_core.dart' show recordHeading;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppButtonStyles,
        AppConfirmTone,
        AppContentCard,
        AppTextStyles,
        showAppConfirmation;

import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import 'change_plan_screen.dart';

class SubscriptionDetailScreen extends StatelessWidget {
  const SubscriptionDetailScreen({super.key, required this.tenantId});
  final String tenantId;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final tenant = controller.tenantById(tenantId);
    final subscription = controller.subscriptionForTenant(tenantId);
    final plan = controller.planById(subscription.planId);
    return Scaffold(
      appBar: AppBar(
        title: Text(recordHeading('Assinatura', subscription.recordNumber)),
      ),
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
                  _Info('Plano', plan.name),
                  _Info('Status', subscription.status.label),
                  _Info('Empresa', tenant.status.label),
                  _Info(
                    'Início',
                    subscription.startedAt == null
                        ? '—'
                        : date(subscription.startedAt!),
                  ),
                  _Info(
                    'Renovação',
                    subscription.renewsAt == null
                        ? '—'
                        : date(subscription.renewsAt!),
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              tenant.status != TenantStatus.active
                  ? 'A empresa não está liberada administrativamente. Ativar a assinatura não libera a empresa.'
                  : subscription.expiredAt(DateTime.now())
                  ? 'Plano vencido em ${date(subscription.renewsAt!)}. São 7 dias normais; depois, os agendamentos novos pausam e, passado o último agendamento marcado, o acesso da equipe pausa. A renovação paga por fora chega em Pendências.'
                  : !subscription.validAt(DateTime.now())
                  ? 'Empresa liberada, mas a operação está bloqueada pela assinatura.'
                  : 'Empresa e assinatura permitem operar, conforme as permissões dos usuários.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Assinatura e empresa têm controles independentes. Alterar o plano mantém a situação da assinatura.',
            ),
            const SizedBox(height: 22),
            // Manager subscription (E2): exceptions such as a payment of
            // several months or a courtesy.
            if (subscription.managed &&
                subscription.renewsAt != null &&
                subscription.status != SubscriptionStatus.pending) ...[
              FilledButton.icon(
                onPressed: controller.busy
                    ? null
                    : () => _renewUntil(context, subscription),
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Renovar até'),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: controller.busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChangePlanScreen(subscriptionId: subscription.id),
                      ),
                    ),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Alterar plano'),
            ),
            const SizedBox(height: 8),
            if (subscription.status != SubscriptionStatus.active) ...[
              FilledButton.icon(
                onPressed: controller.busy
                    ? null
                    : () => _activate(context, subscription),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Ativar assinatura'),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton(
              style: AppButtonStyles.dangerOutlined,
              onPressed:
                  subscription.status == SubscriptionStatus.cancelled ||
                      controller.busy
                  ? null
                  : () => _cancel(context, subscription),
              child: const Text('Cancelar assinatura'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activate(
    BuildContext context,
    Subscription subscription,
  ) async {
    final confirmed = await showAppConfirmation(
      context,
      title: 'Ativar assinatura?',
      message:
          'A assinatura será ativada administrativamente, sem cobrança automática. Uma empresa suspensa continuará suspensa.',
      confirmLabel: 'Ativar assinatura',
      cancelLabel: 'Voltar',
    );
    if (confirmed && context.mounted) {
      await AppScope.of(context).updateSubscription(
        subscription.id,
        subscription.planId,
        SubscriptionStatus.active,
      );
    }
  }

  /// "Renovar até" (E2): the cycle of the principal manager goes up to the
  /// chosen day, for every petshop of the subscription. The reason is
  /// required and stays in the audit.
  Future<void> _renewUntil(
    BuildContext context,
    Subscription subscription,
  ) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final current = subscription.renewsAt;
    final suggested =
        (current != null && current.isAfter(start) ? current : start).add(
          const Duration(days: 30),
        );
    final day = await showDatePicker(
      context: context,
      initialDate: suggested,
      firstDate: start,
      lastDate: start.add(const Duration(days: 400)),
      helpText: 'Renovar até',
    );
    if (day == null || !context.mounted) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RenewReasonDialog(day: day),
    );
    if (reason == null || !context.mounted) return;
    if (reason.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o motivo da renovação.')),
      );
      return;
    }
    final ok = await AppScope.of(
      context,
    ).renewSubscriptionUntil(subscription.tenantId, day, reason);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assinatura renovada até ${date(day)}.')),
      );
    }
  }

  Future<void> _cancel(BuildContext context, Subscription subscription) async {
    final confirmed = await showAppConfirmation(
      context,
      title: 'Cancelar assinatura?',
      message:
          'As operações online serão bloqueadas pela assinatura. A situação administrativa da empresa será mantida, assim como seus dados e histórico.',
      confirmLabel: 'Cancelar assinatura',
      cancelLabel: 'Voltar',
      tone: AppConfirmTone.danger,
    );
    if (confirmed && context.mounted) {
      await AppScope.of(context).updateSubscription(
        subscription.id,
        subscription.planId,
        SubscriptionStatus.cancelled,
      );
    }
  }
}

/// Reason of "Renovar até", kept by the dialog until it is gone: the
/// answer is the trimmed text, or null for Voltar.
class _RenewReasonDialog extends StatefulWidget {
  const _RenewReasonDialog({required this.day});
  final DateTime day;
  @override
  State<_RenewReasonDialog> createState() => _RenewReasonDialogState();
}

class _RenewReasonDialogState extends State<_RenewReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Renovar até ${date(widget.day)}?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vale para todos os petshops do gestor principal. Use para exceções, como um pagamento de vários meses ou uma cortesia.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Voltar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _reason.text.trim()),
        child: const Text('Renovar'),
      ),
    ],
  );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 15),
    child: Row(
      children: [
        SizedBox(width: 105, child: Text(label, style: AppTextStyles.metadata)),
        Expanded(child: Text(value, style: AppTextStyles.value)),
      ],
    ),
  );
}
