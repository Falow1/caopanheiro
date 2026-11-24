import 'package:equipe_app/domain/policies/transport_review.dart';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/formatters.dart';
import '../../../domain/models.dart';
import '../../transports/widgets/transport_status_chip.dart';

/// Operational stages confirmed by the driver, rather than GPS distance.
class NextTransportSummary extends StatelessWidget {
  const NextTransportSummary({super.key, required this.transport});
  final TransportJob transport;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  transport.type == TransportType.pickup
                      ? Icons.pets_rounded
                      : Icons.home_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(transport.type.label, style: text.titleMedium),
                const SizedBox(width: 12),
                Text(
                  time(transport.displayScheduledAt),
                  style: text.titleMedium?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            TransportStatusChip(status: transport.status),
            if (transportNeedsReview(
              transport.scheduledAt,
              transport.status.name == 'assigned' ? 'ASSIGNED' : '',
            ))
              const Text('Atrasado — precisa de revisão'),
          ],
        ),
        const SizedBox(height: 20),
        Text(transport.petsLabel, style: text.headlineMedium),
        const SizedBox(height: 5),
        Text(
          transport.type == TransportType.pickup
              ? transport.origin.name
              : transport.destination.name,
          style: text.bodyMedium,
        ),
        const SizedBox(height: 20),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RouteStop(
                  label: 'ORIGEM',
                  name: transport.origin.name,
                  address: transport.origin.fullAddress,
                  destination: false,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11, top: 4, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 2,
                      height: 18,
                      child: ColoredBox(color: AppColors.line),
                    ),
                  ),
                ),
                _RouteStop(
                  label: 'DESTINO',
                  name: transport.destination.name,
                  address: transport.destination.fullAddress,
                  destination: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        TransportStageProgress(status: transport.status),
      ],
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.label,
    required this.name,
    required this.address,
    required this.destination,
  });
  final String label, name, address;
  final bool destination;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        destination ? Icons.location_on_rounded : Icons.trip_origin_rounded,
        size: 24,
        color: destination ? AppColors.primary : AppColors.warning,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 3),
            Text(name, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 3),
            Text(address, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}

class TransportStageProgress extends StatelessWidget {
  const TransportStageProgress({super.key, required this.status});
  final TransportStatus status;
  static const _stages = [
    TransportStatus.assigned,
    TransportStatus.goingToOrigin,
    TransportStatus.petCollected,
    TransportStatus.inTransit,
    TransportStatus.delivered,
  ];
  static const _labels = [
    'Atribuído',
    'A caminho da coleta',
    'Pets coletados',
    'Em transporte',
    'Entregue',
  ];
  @override
  Widget build(BuildContext context) {
    final index = _stages.indexOf(status);
    if (index < 0) return Text(status.label);
    return Semantics(
      label: 'Progresso do transporte',
      value: 'Etapa ${index + 1} de 5: ${_labels[index]}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  _labels[index],
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
                ),
                Text(
                  'Etapa ${index + 1} de 5',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                5,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 4 ? 0 : 5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 7,
                        color: i <= index ? AppColors.primary : AppColors.line,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Atualizado pelas confirmações do entregador',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
