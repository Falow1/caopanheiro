import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors, AppTextStyles;
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../domain/models/team_company.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../more/plan_screen.dart';

/// Petshops of this person whose plan is near or past its date (E2), in the
/// order of the list. The warning before the date is only for the principal
/// manager who pays; after it, the whole team sees the notice.
List<(TeamCompany, CompanyBilling)> billingNotices(AppController controller) {
  final companies = controller.companies.isNotEmpty
      ? controller.companies
      : [?controller.company];
  return [
    for (final company in companies)
      if (company.billing case final billing?)
        if (!billing.warning || billing.owner) (company, billing),
  ];
}

/// The window comes back when a phase changes, and once more on the last
/// day before the date.
String billingNoticeKey(
  List<(TeamCompany, CompanyBilling)> notices,
  DateTime now,
) => [
  for (final (company, billing) in notices)
    '${company.id}:${billing.phase}'
        '${billing.warning && billing.daysLeft(now) <= 1 ? ':last' : ''}',
].join('|');

/// Expired plan notice over the main screens of the Equipe (E2): a window in
/// the middle of the screen the first time in the session, then a small
/// notice in a corner that opens it again. Only the principal manager who
/// holds the subscription sees "Pagar agora"; the others are told to talk
/// to the manager of the petshop.
class BillingNoticeHost extends StatefulWidget {
  const BillingNoticeHost({super.key, required this.child});
  final Widget child;

  @override
  State<BillingNoticeHost> createState() => _BillingNoticeHostState();
}

class _BillingNoticeHostState extends State<BillingNoticeHost> {
  bool _reopened = false;

  @override
  Widget build(BuildContext context) {
    // A shell inside another shell shows the notice once.
    if (context.findAncestorWidgetOfExactType<_NoticeMarker>() != null) {
      return widget.child;
    }
    final controller = AppScope.of(context);
    final notices = billingNotices(controller);
    if (notices.isEmpty) return _NoticeMarker(child: widget.child);
    final now = DateTime.now();
    final key = billingNoticeKey(notices, now);
    final open = _reopened || !controller.billingNoticeSeen(key);
    final current = notices.firstWhere(
      (item) => item.$1.id == controller.company?.id,
      orElse: () => notices.first,
    );
    void close() {
      controller.markBillingNoticeSeen(key);
      setState(() => _reopened = false);
    }

    return _NoticeMarker(
      child: Stack(
        children: [
          widget.child,
          if (!open)
            Positioned(
              left: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 88,
              child: _CornerNotice(
                billing: current.$2,
                now: now,
                onTap: () => setState(() => _reopened = true),
              ),
            ),
          if (open)
            Positioned.fill(
              child: _NoticeWindow(
                notices: notices,
                now: now,
                onClose: close,
                onPay: () {
                  close();
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const PlanScreen()));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NoticeMarker extends StatelessWidget {
  const _NoticeMarker({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

String _cornerText(CompanyBilling billing, DateTime now) {
  if (billing.warning) {
    final days = billing.daysLeft(now);
    return days == 0
        ? 'Plano vence hoje'
        : days == 1
        ? 'Plano vence amanhã'
        : 'Plano vence em $days dias';
  }
  if (billing.grace) {
    final deadline = billing.deadlineAt;
    return deadline == null
        ? 'Plano vencido'
        : 'Plano vencido · agenda até ${date(deadline)}';
  }
  return 'Agendamentos pausados';
}

class _CornerNotice extends StatelessWidget {
  const _CornerNotice({
    required this.billing,
    required this.now,
    required this.onTap,
  });
  final CompanyBilling billing;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: billing.bookingsPaused
        ? AppColors.cancelledSurface
        : AppColors.pendingSurface,
    elevation: 2,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              billing.bookingsPaused
                  ? Icons.event_busy_rounded
                  : Icons.schedule_rounded,
              size: 18,
              color: billing.bookingsPaused
                  ? AppColors.cancelledInk
                  : AppColors.pendingInk,
            ),
            const SizedBox(width: 6),
            Text(
              _cornerText(billing, now),
              style: AppTextStyles.strong.copyWith(
                fontSize: 13,
                color: billing.bookingsPaused
                    ? AppColors.cancelledInk
                    : AppColors.pendingInk,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NoticeWindow extends StatelessWidget {
  const _NoticeWindow({
    required this.notices,
    required this.now,
    required this.onClose,
    required this.onPay,
  });
  final List<(TeamCompany, CompanyBilling)> notices;
  final DateTime now;
  final VoidCallback onClose;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final owner = notices.any((item) => item.$2.owner);
    final paused = notices.any((item) => item.$2.bookingsPaused);
    final warning = notices.every((item) => item.$2.warning);
    final first = notices.first.$2;
    final title = warning
        ? _cornerText(first, now)
        : paused
        ? 'Agendamentos pausados'
        : owner
        ? 'Seu plano venceu'
        : 'O plano do petshop venceu';
    final deadline = first.deadlineAt;
    final text = warning
        ? 'Renove até ${first.renewsAt == null ? 'a data' : date(first.renewsAt!)} para não ter interrupção.'
        : paused
        ? 'Ninguém marca nem remarca agendamentos, nem a equipe nem os tutores. Atendimentos já marcados, cancelamentos, clientes, pets e transportes continuam. Depois do último atendimento marcado, o acesso pausa.'
        : 'Tudo continua normal${deadline == null ? '' : ' até ${date(deadline)}'}. Depois, ninguém marca nem remarca agendamentos, nem a equipe nem os tutores.';
    return Stack(
      children: [
        // Same shade as the tips of the screens (AppScreenTour).
        ModalBarrier(
          dismissible: false,
          color: AppColors.navy.withValues(alpha: 0.78),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Material(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        paused
                            ? Icons.event_busy_rounded
                            : Icons.warning_amber_rounded,
                        size: 40,
                        color: paused ? AppColors.danger : AppColors.warning,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(text, textAlign: TextAlign.center),
                      if (notices.length > 1) ...[
                        const SizedBox(height: 12),
                        for (final (company, billing) in notices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${company.name}: ${_cornerText(billing, now)}',
                              style: AppTextStyles.captionMuted,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                      if (!owner) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Fale com o gestor do petshop.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.strong,
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (owner)
                        FilledButton(
                          onPressed: onPay,
                          child: const Text('Pagar agora'),
                        ),
                      TextButton(
                        onPressed: onClose,
                        child: Text(owner ? 'Depois' : 'Entendi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
