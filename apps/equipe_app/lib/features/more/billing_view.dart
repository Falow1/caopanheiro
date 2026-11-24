import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppButtonStyles,
        AppColors,
        AppConfirmTone,
        AppContentCard,
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
import 'export_data_screen.dart';
import 'renewal_screen.dart';

/// Subscription of the principal manager (A1): one plan for all their
/// petshops, plan change asked here and confirmed by the platform.
class BillingView extends StatelessWidget {
  const BillingView({super.key, required this.overview, required this.onDone});
  final BillingOverview overview;

  /// Called after a request or a cancellation, to read the subscription again.
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final waiting = overview.tenants.where((item) => !item.covered).toList();
    final openId = controller.company?.id;
    final extra = overview.plans
        .where((plan) => !plan.free && plan.extraTenantPriceCents > 0)
        .map((plan) => plan.extraTenantPriceCents)
        .fold<int?>(null, (value, item) => value ?? item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTourTarget(
          id: TipTargets.planCurrent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      overview.planName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  _StateBadge(overview.state, overview.stateLabel),
                ],
              ),
              const SizedBox(height: 16),
              AppContentCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (overview.renewsAt != null)
                      _Line(switch (overview.state) {
                        'TRIAL' => 'Teste grátis até',
                        'TRIAL_ENDED' => 'Teste encerrado em',
                        'PAST_DUE' => 'Venceu em',
                        _ => 'Renovação',
                      }, date(overview.renewsAt!)),
                    _Line(
                      overview.trial ? 'Valor no teste' : 'Valor mensal',
                      overview.trial || overview.free
                          ? cents(0)
                          : cents(overview.cycleCents),
                    ),
                    _Line(
                      overview.covered.length == 1
                          ? 'Petshop coberto'
                          : 'Petshops cobertos',
                      overview.covered.isEmpty
                          ? 'Nenhum'
                          : overview.covered
                                .map((item) => item.name)
                                .join(' · '),
                    ),
                    if (overview.cancelAt != null)
                      _Line('Vai para o Grátis em', date(overview.cancelAt!)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (overview.trial) ...[
          const SizedBox(height: 8),
          const Text(
            'No fim do teste, escolha um plano. Sem escolha, o petshop segue a regra do plano vencido.',
            style: AppTextStyles.captionMuted,
          ),
        ],
        if (overview.state == 'TRIAL_ENDED') ...[
          const SizedBox(height: 8),
          Text(
            overview.deadlineAt == null
                ? 'O teste terminou. Escolha um plano pago ou fique no Grátis para continuar.'
                : overview.deadlineAt!.isAfter(DateTime.now())
                ? 'O teste terminou. Escolha um plano pago ou fique no Grátis. Até ${date(overview.deadlineAt!)}, tudo continua normal; depois, ninguém marca nem remarca agendamentos.'
                : 'O teste terminou e os agendamentos novos estão pausados. Escolha um plano pago ou fique no Grátis para voltar na hora.',
            style: AppTextStyles.captionMuted,
          ),
        ],
        if (overview.renewalDue(DateTime.now())) ...[
          const SizedBox(height: 12),
          AppTourTarget(
            id: TipTargets.planRenewal,
            child: _RenewalCard(overview: overview, onDone: onDone),
          ),
        ],
        if (overview.cancelAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'Cancelamento agendado: tudo continua até ${date(overview.cancelAt!)}. Depois, ${_tenantName(overview.cancelKeepTenantId)} vai para o Grátis.',
            style: AppTextStyles.captionMuted,
          ),
        ],
        for (final request in overview.pendingRequests) ...[
          const SizedBox(height: 12),
          AppContentCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.label, style: AppTextStyles.strong),
                      const SizedBox(height: 2),
                      Text(
                        request.direction == 'REFUND'
                            ? 'Devolução de ${cents(request.amountCents)} aguardando a plataforma.'
                            : '${cents(request.amountCents)} aguardando a confirmação do pagamento pela plataforma.',
                        style: AppTextStyles.captionMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        AppTourTarget(
          id: TipTargets.planTenants,
          child: SectionTitle(
            overview.tenants.length == 1 ? 'Seu petshop' : 'Seus petshops',
          ),
        ),
        const SizedBox(height: 10),
        for (final tenant in overview.tenants)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppContentCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tenant.name, style: AppTextStyles.strong),
                            const SizedBox(height: 2),
                            Text(
                              tenant.maxUsers == null
                                  ? '${tenant.users} pessoas'
                                  : '${tenant.users} de ${tenant.maxUsers} pessoas',
                              style: AppTextStyles.captionMuted,
                            ),
                          ],
                        ),
                      ),
                      tenant.phase == 'BLOCKED'
                          ? const AppStatusBadge(
                              label: 'Acesso pausado',
                              background: AppColors.cancelledSurface,
                              foreground: AppColors.cancelledInk,
                            )
                          : tenant.phase == 'BOOKINGS_PAUSED'
                          ? const AppStatusBadge(
                              label: 'Agendamentos pausados',
                              background: AppColors.pendingSurface,
                              foreground: AppColors.pendingInk,
                            )
                          : tenant.covered
                          ? AppStatusBadge(
                              label: overview.free
                                  ? 'Grátis'
                                  : overview.planName,
                              background: AppColors.completedSurface,
                              foreground: AppColors.completedInk,
                            )
                          : AppStatusBadge(
                              label: overview.paid
                                  ? 'Fora da assinatura'
                                  : 'Aguardando plano pago',
                              background: AppColors.pendingSurface,
                              foreground: AppColors.pendingInk,
                            ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    children: [
                      // A copy of the data for the principal manager (E2).
                      if (tenant.covered)
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExportDataScreen(
                                tenantId: tenant.id,
                                tenantName: tenant.name,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Exportar dados'),
                        ),
                      if (tenant.action != null && tenant.id != openId)
                        TextButton.icon(
                          style: tenant.action == 'ADD'
                              ? null
                              : AppButtonStyles.dangerText,
                          onPressed: controller.busy
                              ? null
                              : () => _moveTenant(context, tenant),
                          icon: Icon(
                            tenant.action == 'ADD'
                                ? Icons.add_circle_outline_rounded
                                : Icons.remove_circle_outline_rounded,
                          ),
                          label: Text(
                            tenant.action == 'ADD'
                                ? 'Incluir na assinatura'
                                : 'Tirar da assinatura',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (overview.tenants.any(
          (item) => item.action == 'REMOVE' && item.id == openId,
        ))
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Para tirar o petshop aberto agora, troque de petshop antes.',
              style: AppTextStyles.captionMuted,
            ),
          ),
        if (waiting.isNotEmpty)
          Text(
            overview.paid
                ? 'Fora da assinatura, a equipe não acessa o petshop e os tutores só consultam; os dados ficam guardados.'
                : 'O Grátis cobre 1 petshop. Escolha um plano pago para usar os outros também; os dados ficam guardados.',
            style: AppTextStyles.captionMuted,
          ),
        const SizedBox(height: 22),
        const SectionTitle('Planos'),
        const SizedBox(height: 10),
        AppTourTarget(
          id: TipTargets.planOptions,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final plan in overview.plans)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlanCard(
                    overview: overview,
                    plan: plan,
                    busy: controller.busy,
                    onRequest: () => _request(context, plan),
                  ),
                ),
            ],
          ),
        ),
        if (extra != null)
          Text(
            '+ ${cents(extra)}/mês por petshop extra nos planos pagos.',
            style: AppTextStyles.captionMuted,
          ),
        if (controller.error != null) ...[
          const SizedBox(height: 12),
          Text(controller.error!, style: AppTextStyles.danger),
        ],
        if (overview.canCancel && overview.cancelAt == null) ...[
          const SizedBox(height: 18),
          AppTourTarget(
            id: TipTargets.planCancel,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              onPressed: controller.busy
                  ? null
                  : () async {
                      final done = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              CancelSubscriptionScreen(overview: overview),
                        ),
                      );
                      if (done == true) await onDone();
                    },
              icon: const Icon(Icons.cancel_outlined),
              label: Text(
                overview.state == 'TRIAL_ENDED'
                    ? 'Ficar no Grátis'
                    : 'Cancelar assinatura',
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _tenantName(String? id) => overview.tenants
      .where((item) => item.id == id)
      .map((item) => item.name)
      .fold('o petshop escolhido', (_, name) => name);

  /// Takes an extra petshop out of the paid cycle or brings it back (A1-i).
  Future<void> _moveTenant(BuildContext context, BillingTenant tenant) async {
    final quote = overview.tenantQuote;
    if (quote == null) return;
    final controller = AppScope.of(context);
    final add = tenant.action == 'ADD';
    final next = overview.cycleCents + (add ? 1 : -1) * quote.monthlyCents;
    final confirmed = await showAppConfirmation(
      context,
      title: add
          ? 'Incluir o ${tenant.name} na assinatura?'
          : 'Tirar o ${tenant.name} da assinatura?',
      tone: add ? AppConfirmTone.neutral : AppConfirmTone.danger,
      icon: add
          ? Icons.add_circle_outline_rounded
          : Icons.remove_circle_outline_rounded,
      message: add
          ? 'O petshop volta na hora, para a equipe e os tutores. Você paga a taxa dos dias que faltam até a renovação.'
          : 'A equipe deixa de acessar o petshop e os tutores só consultam. Os dados ficam guardados, e você pode incluir de novo.',
      details: [
        ('Taxa do petshop extra', '${cents(quote.monthlyCents)}/mês'),
        ('Dias restantes', '${quote.days}'),
        (
          add ? 'Valor agora' : 'Devolução',
          cents(add ? quote.addCents : quote.removeCents),
        ),
      ],
      note:
          'Depois: ${cents(next)}/mês. ${add ? 'A plataforma confirma o pagamento.' : 'A plataforma registra a devolução pelo mesmo meio do pagamento.'}',
      confirmLabel: add ? 'Incluir' : 'Tirar',
      cancelLabel: 'Voltar',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await controller.changeAccountTenant(tenant.id, add: add);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            add
                ? 'Petshop de volta. O pagamento vai para a plataforma.'
                : 'Petshop fora da assinatura. A devolução vai para a plataforma.',
          ),
        ),
      );
    }
    await onDone();
  }

  Future<void> _request(BuildContext context, BillingPlanOption plan) async {
    final quote = plan.quote;
    if (quote == null) return;
    final controller = AppScope.of(context);
    final renews = overview.renewsAt == null ? '' : date(overview.renewsAt!);
    final monthly = (quote.nextCycleCents - overview.cycleCents).abs();
    final confirmed = await showAppConfirmation(
      context,
      title: 'Trocar para o ${plan.name}',
      icon: Icons.workspace_premium_outlined,
      message: switch (quote.kind) {
        'UPGRADE' =>
          'A troca vale na hora. Você paga só a diferença dos dias que faltam até a renovação em $renews.',
        'DOWNGRADE' =>
          'A troca vale na hora. Você recebe de volta a diferença dos dias que faltam até a renovação em $renews.',
        _ =>
          'Começa um ciclo de 30 dias quando a plataforma confirmar o pagamento. O valor inclui os petshops extras.',
      },
      details: switch (quote.kind) {
        'UPGRADE' || 'DOWNGRADE' => [
          ('Diferença por mês', cents(monthly)),
          ('Dias restantes', '${quote.days}'),
          (
            quote.direction == 'REFUND' ? 'Devolução' : 'Valor agora',
            cents(quote.amountCents),
          ),
        ],
        _ => [
          ('Primeiro ciclo', cents(quote.amountCents)),
          ('Ciclo', '30 dias'),
        ],
      },
      note:
          '${quote.kind == 'START' ? 'Depois' : 'A partir da renovação'}: ${cents(quote.nextCycleCents)}/mês. '
          '${quote.direction == 'REFUND' ? 'A plataforma aplica a troca e registra a devolução.' : 'O pedido vai para a plataforma. A troca vale quando o pagamento for confirmado.'}',
      confirmLabel: 'Pedir troca',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await controller.requestPlanChange(plan.id);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido enviado à plataforma.')),
      );
    }
    await onDone();
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.overview,
    required this.plan,
    required this.busy,
    required this.onRequest,
  });
  final BillingOverview overview;
  final BillingPlanOption plan;
  final bool busy;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final lines = [
      if (plan.free)
        '${plan.maxTenants ?? 1} petshop · até ${plan.maxUsers ?? '-'} pessoas'
      else if (plan.maxUsers != null)
        'Até ${plan.maxUsers} pessoas por petshop',
      plan.tutorApp
          ? 'App do tutor: agendamento e avisos'
          : 'Só agenda, sem o app do tutor',
      if (plan.transport) 'Transporte com entregador e acompanhamento',
    ];
    return AppContentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                plan.free
                    ? 'R\$ 0, sempre'
                    : '${cents(plan.monthlyPriceCents)}/mês',
                style: AppTextStyles.strong,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (plan.current)
            Align(
              alignment: Alignment.centerLeft,
              child: AppStatusBadge(
                label: overview.trial ? 'Plano do teste' : 'Plano atual',
                background: AppColors.mint,
                foreground: AppColors.primaryDark,
              ),
            )
          else if (plan.free)
            const Text(
              'Para ir ao Grátis, use Cancelar assinatura.',
              style: AppTextStyles.captionMuted,
            )
          else if (plan.blockedReason != null)
            Text(plan.blockedReason!, style: AppTextStyles.captionMuted)
          else if (plan.quote != null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: busy || overview.hasPendingChange ? null : onRequest,
                child: Text(
                  overview.hasPendingChange
                      ? 'Pedido em análise'
                      : plan.quote!.kind == 'START'
                      ? 'Escolher este plano'
                      : 'Pedir troca',
                ),
              ),
            ),
          if (plan.current && overview.trial && plan.quote != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: busy || overview.hasPendingChange ? null : onRequest,
                child: const Text('Continuar neste plano'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge(this.state, this.label);
  final String state;
  final String label;
  @override
  Widget build(BuildContext context) => switch (state) {
    'ACTIVE' => AppStatusBadge(
      label: label,
      background: AppColors.completedSurface,
      foreground: AppColors.completedInk,
    ),
    'TRIAL' => AppStatusBadge(
      label: label,
      background: AppColors.progressSurface,
      foreground: AppColors.progressInk,
    ),
    'TRIAL_ENDED' || 'PAST_DUE' => AppStatusBadge(
      label: label,
      background: AppColors.pendingSurface,
      foreground: AppColors.pendingInk,
    ),
    _ => AppStatusBadge(
      label: label,
      background: AppColors.inactiveSurface,
      foreground: AppColors.inactiveInk,
    ),
  };
}

/// Renewal of the paid plan (E2): from 7 days before the date and after it,
/// with what happens next and "Pagar agora".
class _RenewalCard extends StatelessWidget {
  const _RenewalCard({required this.overview, required this.onDone});
  final BillingOverview overview;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final renews = overview.renewsAt;
    final deadline = overview.deadlineAt;
    final paused = deadline != null && !deadline.isAfter(now);
    final title = !overview.pastDue
        ? 'Seu plano vence em ${renews == null ? '-' : date(renews)}'
        : paused
        ? 'Agendamentos pausados'
        : 'Seu plano venceu';
    final text = !overview.pastDue
        ? 'Renove antes da data para não ter interrupção.'
        : paused
        ? 'Ninguém marca nem remarca agendamentos. O que já está marcado continua; depois do último atendimento marcado, o acesso pausa. Renove para tudo voltar na hora.'
        : 'Tudo continua normal até ${deadline == null ? '-' : date(deadline)}. Depois, ninguém marca nem remarca agendamentos, nem a equipe nem os tutores.';
    return AppContentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                overview.pastDue
                    ? Icons.warning_amber_rounded
                    : Icons.event_repeat_rounded,
                color: overview.pastDue ? AppColors.warning : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: AppTextStyles.strong)),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: AppTextStyles.captionMuted),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: overview.renewalPending
                ? const Text(
                    'Renovação aguardando a confirmação da plataforma.',
                    style: AppTextStyles.strong,
                  )
                : FilledButton(
                    onPressed: () async {
                      final done = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => RenewalScreen(overview: overview),
                        ),
                      );
                      if (done == true) await onDone();
                    },
                    child: const Text('Pagar agora'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppTextStyles.captionMuted)),
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
  );
}

/// Free cancellation (A1-j): at the end of the cycle, or now with the refund
/// of the remaining days. The manager chooses the petshop kept on the free
/// plan; the others wait for a paid plan, with their data kept (A1-t).
class CancelSubscriptionScreen extends StatefulWidget {
  const CancelSubscriptionScreen({super.key, required this.overview});
  final BillingOverview overview;
  @override
  State<CancelSubscriptionScreen> createState() =>
      _CancelSubscriptionScreenState();
}

class _CancelSubscriptionScreenState extends State<CancelSubscriptionScreen> {
  late bool _endOfCycle = _offersEndOfCycle;
  late String _keep = widget.overview.tenants.isEmpty
      ? ''
      : (widget.overview.covered.isEmpty
                ? widget.overview.tenants
                : widget.overview.covered)
            .first
            .id;

  bool get _offersEndOfCycle =>
      widget.overview.state != 'TRIAL_ENDED' &&
      widget.overview.renewsAt != null;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final overview = widget.overview;
    final quote = overview.cancelQuote;
    final renews = overview.renewsAt == null ? '' : date(overview.renewsAt!);
    final ended = overview.state == 'TRIAL_ENDED';
    return Scaffold(
      appBar: AppBar(
        title: Text(ended ? 'Ficar no Grátis' : 'Cancelar assinatura'),
      ),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${overview.planName} · ${overview.tenants.length == 1 ? '1 petshop' : '${overview.tenants.length} petshops'}'
              '${overview.renewsAt == null || ended ? '' : ' · ${overview.trial ? 'teste até' : 'renovação em'} $renews'}',
              style: AppTextStyles.captionMuted,
            ),
            if (_offersEndOfCycle) ...[
              const SizedBox(height: 18),
              const SectionTitle('Quando cancelar'),
              const SizedBox(height: 8),
              _Choice(
                selected: _endOfCycle,
                title: 'Ao fim do ciclo, em $renews',
                text:
                    'Tudo continua até $renews. Depois, o petshop escolhido vai para o Grátis.',
                onTap: () => setState(() => _endOfCycle = true),
              ),
              _Choice(
                selected: !_endOfCycle,
                title: 'Agora',
                text: quote.amountCents > 0
                    ? 'Vai para o Grátis hoje. Você recebe ${cents(quote.amountCents)}${quote.withdrawal ? ', o valor inteiro da primeira cobrança (arrependimento em até 7 dias)' : ' dos ${quote.days} dias restantes'}.'
                    : 'Vai para o Grátis hoje, sem valor a devolver.',
                onTap: () => setState(() => _endOfCycle = false),
              ),
            ],
            if (overview.tenants.length > 1) ...[
              const SizedBox(height: 18),
              const SectionTitle('Qual petshop fica no Grátis?'),
              const SizedBox(height: 8),
              for (final tenant in overview.tenants)
                _Choice(
                  selected: _keep == tenant.id,
                  title: tenant.name,
                  text: '${tenant.users} pessoas',
                  onTap: () => setState(() => _keep = tenant.id),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              '${overview.tenants.length > 1 ? 'Os outros ficam "aguardando plano pago", com os dados guardados. ' : ''}'
              'No Grátis: até 5 pessoas, sem o app do tutor e sem transporte. Os tutores veem o petshop só para consulta. '
              'Acima de 5 pessoas, ninguém é removido, mas não dá para incluir mais.',
              style: AppTextStyles.captionMuted,
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 12),
              Text(controller.error!, style: AppTextStyles.danger),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: controller.busy || _keep.isEmpty
                  ? null
                  : () => _confirm(context),
              child: Text(ended ? 'Ficar no Grátis' : 'Cancelar assinatura'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final controller = AppScope.of(context);
    final overview = widget.overview;
    final endOfCycle = _offersEndOfCycle && _endOfCycle;
    final keep = overview.tenants.firstWhere((item) => item.id == _keep);
    final confirmed = await showAppConfirmation(
      context,
      title: endOfCycle
          ? 'Cancelar ao fim do ciclo?'
          : 'Ir para o Grátis agora?',
      tone: AppConfirmTone.danger,
      icon: Icons.cancel_outlined,
      message: endOfCycle
          ? 'O plano continua até ${date(overview.renewsAt!)}. Depois, ${keep.name} fica no Grátis.'
          : '${keep.name} fica no Grátis hoje.',
      details: [
        if (!endOfCycle && overview.cancelQuote.amountCents > 0)
          ('Devolução', cents(overview.cancelQuote.amountCents)),
      ],
      confirmLabel: 'Confirmar',
      cancelLabel: 'Voltar',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await controller.cancelSubscription(
      endOfCycle: endOfCycle,
      keepTenantId: keep.id,
    );
    if (!context.mounted || !ok) return;
    await controller.refreshCompanyEntitlements();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          endOfCycle
              ? 'Cancelamento agendado.'
              : 'Assinatura cancelada. ${keep.name} está no Grátis.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.title,
    required this.text,
    required this.onTap,
  });
  final bool selected;
  final String title;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.strong),
                    const SizedBox(height: 2),
                    Text(text, style: AppTextStyles.captionMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
