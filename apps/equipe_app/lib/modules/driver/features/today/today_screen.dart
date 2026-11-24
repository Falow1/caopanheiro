import '../../domain/models.dart';
import 'package:equipe_app/domain/policies/transport_review.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../../../core/screen_tips.dart';
import 'package:equipe_app/core/role_notice_bell.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../transports/transport_actions.dart';
import 'widgets/next_transport_summary.dart';
import '../transports/transport_detail_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onViewAll});
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.driverToday,
    tips: TeamTips.driverToday,
    ready: !AppScope.of(context).busy,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final profile = controller.profile;
    // The outgoing route can rebuild after signOut clears the session.
    final activeTenant = controller.activeTenant;
    if (profile == null || activeTenant == null) {
      return const SizedBox.shrink();
    }
    bool needsReview(transport) => transportNeedsReview(
      transport.scheduledAt,
      transport.status == TransportStatus.assigned ? 'ASSIGNED' : '',
    );
    final review = controller.todayTransports.where(needsReview).toList();
    final transports = controller.todayTransports
        .where((t) => !needsReview(t))
        .toList();
    final next = transports.isEmpty ? null : transports.first;
    final now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          padding: TeamLayout.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Hoje', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Brand(compact: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${greeting(now)}, ${profile.name.split(' ').first}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('${activeTenant.tenantName} · ${fullDate(now)}'),
                      ],
                    ),
                  ),
                  RoleNoticeBell(
                    source: controller.noticesSource,
                    tenantId: controller.activeTenantId,
                    refreshKey: (controller.updatedAt, controller.liveRevision),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (review.isNotEmpty) ...[
                const Text('Atrasados — aguardam revisão do atendente'),
                const Text(
                  'Confirme com o atendimento a remarcação ou o cancelamento antes de iniciar.',
                ),
                for (final transport in review)
                  TransportCard(
                    transport: transport,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TransportDetailScreen(transportId: transport.id),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              if (next == null)
                const EmptyTransportState(
                  title: 'Nenhum transporte pendente',
                  message: 'As novas tarefas atribuídas aparecerão aqui.',
                )
              else ...[
                const Text(
                  'PRÓXIMA TAREFA',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                AppTourTarget(
                  id: TipTargets.driverNext,
                  child: AppContentCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NextTransportSummary(transport: next),
                        const SizedBox(height: 20),
                        TransportPrimaryAction(
                          status: next.status,
                          busy: controller.busy,
                          enabled: !controller.readOnly,
                          onPressed: () =>
                              performPrimaryAction(context, next.id),
                        ),
                        const SizedBox(height: 5),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TransportDetailScreen(transportId: next.id),
                            ),
                          ),
                          child: const Text('Ver detalhes'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (transports.length > 1) ...[
                  const SizedBox(height: 26),
                  SectionTitle(
                    'Transportes seguintes',
                    action: AppTourTarget(
                      id: TipTargets.driverAll,
                      child: TextButton(
                        onPressed: onViewAll,
                        child: const Text('Ver todos'),
                      ),
                    ),
                  ),
                  ...transports
                      .skip(1)
                      .map(
                        (transport) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TransportCard(
                            transport: transport,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransportDetailScreen(
                                  transportId: transport.id,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
