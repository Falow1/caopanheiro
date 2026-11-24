import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../../../core/screen_tips.dart';

import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import 'transport_detail_screen.dart';

class TransportsScreen extends StatefulWidget {
  const TransportsScreen({super.key});

  @override
  State<TransportsScreen> createState() => _TransportsScreenState();
}

class _TransportsScreenState extends State<TransportsScreen> {
  bool _nextDays = false;
  TransportType? _type;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.driverTransports,
    tips: TeamTips.driverTransports,
    ready: !AppScope.of(context).busy,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final now = DateTime.now();
    final items = controller.tenantTransports.where((item) {
      if (item.status.finished) return false;
      final periodMatches = _nextDays
          ? !isSameDay(item.scheduledAt, now) && item.scheduledAt.isAfter(now)
          : isSameDay(item.scheduledAt, now) || item.scheduledAt.isBefore(now);
      return periodMatches && (_type == null || item.type == _type);
    }).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: TeamLayout.header,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Transportes',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  AppTourTarget(
                    id: TipTargets.driverPeriod,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Hoje e atrasados'),
                        ),
                        ButtonSegment(value: true, label: Text('Próximos')),
                      ],
                      selected: {_nextDays},
                      onSelectionChanged: (value) =>
                          setState(() => _nextDays = value.first),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppTourTarget(
                    id: TipTargets.driverKind,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: _type == null,
                          onSelected: (_) => setState(() => _type = null),
                        ),
                        ChoiceChip(
                          label: const Text('Coleta'),
                          selected: _type == TransportType.pickup,
                          onSelected: (_) =>
                              setState(() => _type = TransportType.pickup),
                        ),
                        ChoiceChip(
                          label: const Text('Retorno'),
                          selected: _type == TransportType.returnTrip,
                          onSelected: (_) =>
                              setState(() => _type = TransportType.returnTrip),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyTransportState(
                      title: 'Nenhum transporte encontrado',
                      message:
                          'Altere os filtros ou aguarde uma nova atribuição.',
                    )
                  : ListView.separated(
                      padding: TeamLayout.list,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final transport = items[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (index == 0 ||
                                !isSameDay(
                                  transport.displayScheduledAt,
                                  items[index - 1].displayScheduledAt,
                                )) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8,
                                  top: 6,
                                ),
                                child: Text(
                                  dateHeader(transport.displayScheduledAt),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                            AppTourTarget(
                              id: TipTargets.driverCard,
                              child: TransportCard(
                                transport: transport,
                                showDate: _nextDays,
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
                          ],
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
