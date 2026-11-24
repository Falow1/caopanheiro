import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppColors,
        AppContentCard,
        AppScreenTips,
        AppStatusBadge,
        AppTextStyles,
        AppTourTarget,
        showAppConfirmation;
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/screen_tips.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import 'billing_models.dart';
import 'support_screen.dart';

/// "Pagar agora" (E2, path A). Until payments exist inside the app (P2),
/// the manager pays outside it and taps "Já paguei"; the platform checks the
/// money in its Pendências and confirms 30 more days. Pix, card and boleto
/// appear as coming soon: nothing is charged or collected here.
class RenewalScreen extends StatelessWidget {
  const RenewalScreen({super.key, required this.overview});
  final BillingOverview overview;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final quote = overview.renewalQuote;
    final renews = overview.renewsAt;
    final covered = overview.covered;
    return AppScreenTips(
      screen: TipScreens.renewal,
      tips: TeamTips.renewal,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pagar agora')),
        body: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTourTarget(
                id: TipTargets.renewalValue,
                child: AppContentCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        quote == null ? '-' : cents(quote.amountCents),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${overview.planName} · ${quote?.days ?? 30} dias · '
                        '${covered.length == 1 ? '1 petshop' : '${covered.length} petshops'}',
                        style: AppTextStyles.captionMuted,
                      ),
                      const SizedBox(height: 12),
                      if (renews != null)
                        _Line(
                          overview.pastDue ? 'Venceu em' : 'Vence em',
                          date(renews),
                        ),
                      if (overview.pastDue && overview.deadlineAt != null)
                        _Line('Agendamentos até', date(overview.deadlineAt!)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const SectionTitle('Como pagar'),
              const SizedBox(height: 10),
              AppTourTarget(
                id: TipTargets.renewalMethods,
                child: PaymentMethodsSoon(payments: overview.onlinePayments),
              ),
              const SizedBox(height: 10),
              const Text(
                'Por enquanto, pague pelo combinado com a plataforma, por exemplo por Pix. Se precisar dos dados para pagar, fale com o Suporte da plataforma. Depois toque em Já paguei.',
                style: AppTextStyles.captionMuted,
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  ),
                  icon: const Icon(Icons.support_agent_outlined),
                  label: const Text('Suporte da plataforma'),
                ),
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 8),
                Text(controller.error!, style: AppTextStyles.danger),
              ],
              const SizedBox(height: 16),
              AppTourTarget(
                id: TipTargets.renewalPaid,
                child: overview.renewalPending
                    ? const AppContentCard(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.hourglass_top_rounded,
                              color: AppColors.orange,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Aguardando a confirmação da plataforma. Quando ela confirmar, o plano ganha mais 30 dias.',
                              ),
                            ),
                          ],
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: controller.busy || quote == null
                            ? null
                            : () => _paid(context, quote),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Já paguei'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _paid(BuildContext context, RenewalQuote quote) async {
    final controller = AppScope.of(context);
    final confirmed = await showAppConfirmation(
      context,
      title: 'Avisar a plataforma do pagamento?',
      icon: Icons.check_circle_outline_rounded,
      message:
          'Use depois de pagar. A plataforma confere o pagamento e confirma a renovação.',
      details: [
        ('Valor', cents(quote.amountCents)),
        ('Renovação', '${quote.days} dias'),
      ],
      confirmLabel: 'Já paguei',
      cancelLabel: 'Voltar',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await controller.requestRenewal();
    if (!context.mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aviso enviado. Aguardando a confirmação da plataforma.'),
      ),
    );
    Navigator.of(context).pop(true);
  }
}

/// Pix, card and boleto inside the app, shown as coming soon until the
/// payment provider exists (P2/P3). Disabled: they collect nothing.
class PaymentMethodsSoon extends StatelessWidget {
  const PaymentMethodsSoon({super.key, required this.payments});
  final OnlinePayments payments;

  static IconData _icon(String method) => switch (method) {
    'PIX' => Icons.qr_code_2_rounded,
    'CARD' => Icons.credit_card_rounded,
    'BOLETO' => Icons.receipt_long_outlined,
    _ => Icons.payments_outlined,
  };

  @override
  Widget build(BuildContext context) => AppContentCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Column(
      children: [
        for (final method in payments.methods)
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: false,
            leading: Icon(_icon(method)),
            title: Text(OnlinePayments.label(method)),
            subtitle: const Text('Pagamento pelo app'),
            trailing: const AppStatusBadge(
              label: 'Em breve',
              background: AppColors.inactiveSurface,
              foreground: AppColors.inactiveInk,
            ),
          ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.captionMuted)),
        Text(value, style: AppTextStyles.strong),
      ],
    ),
  );
}

/// "Receber pelo app" (E2): the payment of the tutor to the petshop in the
/// app is announced as coming soon; nothing is configured or charged.
Future<void> showOnlinePaymentsSoon(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialog) => AlertDialog(
    title: const Text('Receber pelo app'),
    content: const SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Em breve, o tutor vai poder pagar o atendimento pelo app. Por enquanto, receba no petshop, como hoje.',
          ),
          SizedBox(height: 12),
          PaymentMethodsSoon(payments: OnlinePayments()),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialog).pop(),
        child: const Text('Entendi'),
      ),
    ],
  ),
);
