import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppColors,
        AppContentCard,
        AppScreenTips,
        AppStatusBadge,
        AppTextStyles,
        AppTourTarget;
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/screen_tips.dart';
import '../../core/widgets.dart';
import '../../domain/models/team_company.dart';
import '../../state/app_scope.dart';
import '../more/confirm_sign_out.dart';
import '../more/export_data_screen.dart';
import '../more/plan_screen.dart';
import '../more/support_screen.dart';
import 'login_screen.dart';

/// Access paused (E2) for the principal manager whose petshops are all
/// paused: by an expired plan after the last booked day, or by the platform.
/// Nothing was deleted. From here they renew (Plan), export the data, or
/// talk to Support; the team only sees "Fale com o gestor do petshop".
class AccessPausedScreen extends StatelessWidget {
  const AccessPausedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final companies = controller.pausedAccess;
    return AppScreenTips(
      screen: TipScreens.accessPaused,
      tips: TeamTips.accessPaused,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Acesso pausado'),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: () => _signOut(context),
              child: const Text('Sair'),
            ),
          ],
        ),
        body: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Os dados continuam guardados. A equipe vê que precisa falar com você.',
                style: AppTextStyles.captionMuted,
              ),
              const SizedBox(height: 16),
              for (final (index, company) in companies.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: index == 0
                      ? AppTourTarget(
                          id: TipTargets.pausedShop,
                          child: _PausedCard(company: company, first: true),
                        )
                      : _PausedCard(company: company),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final controller = AppScope.of(context);
    if (controller.busy || !await askSignOut(context) || !context.mounted) {
      return;
    }
    controller.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _PausedCard extends StatelessWidget {
  const _PausedCard({required this.company, this.first = false});
  final PausedCompany company;
  final bool first;

  void _open(BuildContext context, Widget screen) {
    AppScope.of(context).openPausedCompany(company);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final block = company.billing?.blockFrom;
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!company.suspended && company.owner)
          FilledButton.icon(
            onPressed: () => _open(context, const PlanScreen()),
            icon: const Icon(Icons.autorenew_rounded),
            label: const Text('Renovar'),
          ),
        if (company.suspended)
          FilledButton.icon(
            onPressed: () => _open(context, const SupportScreen()),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Suporte da plataforma'),
          ),
        if (!company.suspended)
          OutlinedButton.icon(
            onPressed: () => _open(
              context,
              ExportDataScreen(tenantId: company.id, tenantName: company.name),
            ),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Exportar dados'),
          ),
        OutlinedButton.icon(
          onPressed: () => _open(
            context,
            company.suspended ? const PlanScreen() : const SupportScreen(),
          ),
          icon: Icon(
            company.suspended
                ? Icons.workspace_premium_outlined
                : Icons.support_agent_outlined,
          ),
          label: Text(company.suspended ? 'Plano e assinatura' : 'Suporte'),
        ),
      ],
    );
    return AppContentCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  company.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AppStatusBadge(
                label: company.suspended
                    ? 'Pausado pela plataforma'
                    : 'Plano vencido',
                background: AppColors.cancelledSurface,
                foreground: AppColors.cancelledInk,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            company.suspended
                ? 'A plataforma pausou o acesso deste petshop. Os tutores só consultam. Para saber o motivo e voltar, fale com o Suporte da plataforma.'
                : 'O plano venceu e os 7 dias de prazo acabaram${block == null ? '' : ' (pausado desde ${date(block)})'}. A equipe não acessa o petshop e os tutores só consultam. Renove e tudo volta na hora.',
          ),
          const SizedBox(height: 14),
          first
              ? AppTourTarget(id: TipTargets.pausedActions, child: actions)
              : actions,
        ],
      ),
    );
  }
}
