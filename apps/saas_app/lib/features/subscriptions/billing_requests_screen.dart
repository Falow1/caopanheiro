import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppConfirmTone,
        AppContentCard,
        AppStatusBadge,
        AppTextStyles,
        showAppConfirmation;
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import '../support/support_requests_screen.dart';

/// Cents as Brazilian money, without the floating point of `money`.
String cents(int value) {
  final whole = (value.abs() ~/ 100).toString();
  final buffer = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) buffer.write('.');
    buffer.write(whole[index]);
  }
  return '${value < 0 ? '-' : ''}R\$ $buffer,${(value.abs() % 100).toString().padLeft(2, '0')}';
}

/// "Pendências" of the dashboard (A1-s): what waits for the platform. The
/// counts come with every refresh, so the board follows the live signal.
class PendingBoard extends StatelessWidget {
  const PendingBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final queue = controller.billingQueue;
    final support = controller.supportWaitingCount;
    // Each row opens only its own category; null is the support queue.
    final rows = <(int, String, String?)>[
      (
        queue.planChanges,
        queue.planChanges == 1
            ? 'pedido de troca de plano'
            : 'pedidos de troca de plano',
        'PLAN_CHANGE',
      ),
      (
        queue.charges,
        queue.charges == 1 ? 'pagamento a confirmar' : 'pagamentos a confirmar',
        'CHARGE',
      ),
      (
        queue.refunds,
        queue.refunds == 1 ? 'devolução a registrar' : 'devoluções a registrar',
        'REFUND',
      ),
      (
        queue.renewals,
        queue.renewals == 1
            ? 'renovação a confirmar'
            : 'renovações a confirmar',
        'RENEWAL',
      ),
      (
        support,
        support == 1
            ? 'suporte aguardando resposta'
            : 'suportes aguardando resposta',
        null,
      ),
    ];
    return AppContentCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pendências', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (queue.subscriptionCount + support == 0)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Nada aguardando a plataforma.',
                style: AppTextStyles.captionMuted,
              ),
            ),
          for (final (count, label, kind) in rows)
            if (count > 0)
              InkWell(
                key: ValueKey('pending-${kind ?? 'SUPPORT'}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => kind == null
                        ? const SupportRequestsScreen()
                        : BillingRequestsScreen(kind: kind),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: AppColors.orange,
                        child: Text(
                          kind == null &&
                                  queue.supportCapped &&
                                  !controller.supportLoaded
                              ? '200+'
                              : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(label)),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Categories of the requests, in the order of the dashboard.
const billingCategories = [
  ('PLAN_CHANGE', 'Trocas de plano'),
  ('CHARGE', 'Pagamentos a confirmar'),
  ('REFUND', 'Devoluções a registrar'),
  ('RENEWAL', 'Renovações a confirmar'),
];

/// Subscription requests waiting for the platform, oldest first: only the
/// [kind] chosen on the dashboard, or every category under its own title.
class BillingRequestsScreen extends StatelessWidget {
  const BillingRequestsScreen({super.key, this.kind});
  final String? kind;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final all = controller.billingQueue.items;
    final groups = [
      for (final (id, title) in billingCategories)
        if (kind == null || kind == id)
          (title, all.where((item) => item.kind == id).toList()),
      if (kind == null)
        (
          'Outros pedidos',
          all
              .where(
                (item) =>
                    !billingCategories.any((entry) => entry.$1 == item.kind),
              )
              .toList(),
        ),
    ].where((group) => kind != null || group.$2.isNotEmpty).toList();
    final items = [for (final group in groups) ...group.$2];
    final title = kind == null
        ? 'Pedidos de assinatura'
        : billingCategories.firstWhere((entry) => entry.$1 == kind).$2;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const Text(
              'Pedidos dos gestores principais. Antes dos pagamentos no app, o valor é pago ou devolvido por fora: confirme aqui para o servidor aplicar.',
              style: AppTextStyles.captionMuted,
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Nenhum pedido aguardando.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final (groupTitle, groupItems) in groups) ...[
              if (kind == null && groupItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Text(
                    '$groupTitle (${groupItems.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              for (final item in groupItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BillingRequestScreen(request: item),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 8,
                      ),
                      title: Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        '${item.ownerName.isEmpty ? 'Gestor' : item.ownerName} · ${item.detail}',
                      ),
                      trailing: Text(
                        cents(item.amountCents),
                        style: AppTextStyles.strong,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One request: the platform checks the payment (or the refund) made
/// outside the app, then confirms; a refusal needs a reason.
class BillingRequestScreen extends StatefulWidget {
  const BillingRequestScreen({super.key, required this.request});
  final BillingRequest request;
  @override
  State<BillingRequestScreen> createState() => _BillingRequestScreenState();
}

class _BillingRequestScreenState extends State<BillingRequestScreen> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _confirmLabel => switch (widget.request.kind) {
    'PLAN_CHANGE' => 'Confirmar e aplicar',
    'CHARGE' => 'Confirmar pagamento',
    'REFUND' => 'Registrar devolução feita',
    'RENEWAL' => 'Confirmar renovação',
    _ => 'Confirmar',
  };

  String get _guidance => switch ((
    widget.request.kind,
    widget.request.direction,
  )) {
    ('PLAN_CHANGE', 'REFUND') =>
      'A troca vale na hora. Depois de aplicar, a devolução aparece em Pendências para registrar quando for feita.',
    ('PLAN_CHANGE', _) =>
      'Confirme que o pagamento chegou antes de aplicar. A troca vale na hora.',
    ('CHARGE', _) =>
      'O petshop extra já está em uso. Confirme quando o pagamento chegar.',
    ('RENEWAL', _) =>
      'O gestor avisou que pagou por fora. Confirme quando o pagamento chegar: a assinatura ganha mais 30 dias e os petshops voltam na hora.',
    _ =>
      'Registre depois de devolver o valor pelo mesmo meio do pagamento. A taxa do provedor fica com a plataforma.',
  };

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final item = widget.request;
    final lines = [
      ('Gestor principal', item.ownerName.isEmpty ? '-' : item.ownerName),
      if (item.kind == 'PLAN_CHANGE')
        ('Troca', item.detail)
      else if (item.kind == 'RENEWAL')
        ('Renovação', item.detail)
      else
        ('Motivo', item.detail),
      if (item.tenantNames.isNotEmpty)
        (
          item.tenantNames.length == 1 ? 'Petshop' : 'Petshops',
          item.tenantNames.join(' · '),
        ),
      if (item.days != null) ('Dias restantes', '${item.days}'),
      (
        item.direction == 'REFUND' ? 'Devolução' : 'Valor proporcional',
        cents(item.amountCents),
      ),
      if (item.createdAt != null) ('Pedido em', dateTime(item.createdAt!)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppStatusBadge(
              label: 'Aguardando a plataforma',
              background: AppColors.pendingSurface,
              foreground: AppColors.pendingInk,
            ),
          ),
          const SizedBox(height: 14),
          AppContentCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                for (final (label, value) in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(label, style: AppTextStyles.captionMuted),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            value,
                            textAlign: TextAlign.end,
                            style: AppTextStyles.strong,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_guidance, style: AppTextStyles.captionMuted),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            Text(controller.error!, style: AppTextStyles.danger),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: controller.busy || controller.readOnly
                ? null
                : () => _decide(approve: true),
            child: Text(_confirmLabel),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _reason,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Motivo da recusa',
              helperText:
                  'Obrigatório para recusar. O gestor vê o pedido recusado.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: controller.busy || controller.readOnly
                ? null
                : () => _decide(approve: false),
            child: const Text('Recusar pedido'),
          ),
        ],
      ),
    );
  }

  Future<void> _decide({required bool approve}) async {
    final controller = AppScope.of(context);
    final item = widget.request;
    final reason = _reason.text.trim();
    if (!approve && reason.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o motivo da recusa.')),
      );
      return;
    }
    final confirmed = await showAppConfirmation(
      context,
      title: approve ? _confirmLabel : 'Recusar pedido?',
      tone: approve ? AppConfirmTone.neutral : AppConfirmTone.danger,
      message: approve
          ? item.kind == 'PLAN_CHANGE'
                ? 'O plano muda na hora em todos os petshops do gestor.'
                : item.kind == 'RENEWAL'
                ? 'A assinatura ganha mais 30 dias e os petshops do gestor voltam na hora.'
                : 'O pedido sai das Pendências.'
          : 'O plano não muda e o pedido sai das Pendências.',
      details: [
        (
          item.direction == 'REFUND' ? 'Devolução' : 'Valor',
          cents(item.amountCents),
        ),
      ],
      confirmLabel: approve ? 'Confirmar' : 'Recusar',
      cancelLabel: 'Voltar',
    );
    if (!confirmed || !mounted) return;
    final ok = await controller.decideBillingRequest(
      item.id,
      approve: approve,
      reason: approve ? '' : reason,
    );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !approve
              ? 'Pedido recusado.'
              : item.kind == 'RENEWAL'
              ? 'Renovação confirmada.'
              : 'Pedido confirmado.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }
}
