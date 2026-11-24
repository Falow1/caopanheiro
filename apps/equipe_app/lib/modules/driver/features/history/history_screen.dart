import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../../../core/screen_tips.dart';

import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../transports/transport_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.driverHistory,
    tips: TeamTips.driverHistory,
    ready: !AppScope.of(context).busy,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final items = AppScope.of(context).history;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: TeamLayout.header,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Histórico',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Transportes concluídos permanecem disponíveis para consulta.',
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyTransportState(
                      title: 'Histórico vazio',
                      message: 'Os transportes concluídos aparecerão aqui.',
                    )
                  : ListView.separated(
                      padding: TeamLayout.list,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final transport = items[index];
                        return AppTourTarget(
                          id: TipTargets.driverHistoryCard,
                          child: Card(
                            child: ListTile(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TransportDetailScreen(
                                    transportId: transport.id,
                                  ),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 17,
                                vertical: 10,
                              ),
                              title: Text(
                                transport.petsLabel,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                '${date(transport.displayScheduledAt)} · ${transport.type.label}\n${time(transport.displayScheduledAt)}${transport.deliveredAt == null ? '' : ' → ${time(transport.deliveredAt!)}'}',
                              ),
                              trailing: TransportStatusChip(
                                status: transport.status,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
