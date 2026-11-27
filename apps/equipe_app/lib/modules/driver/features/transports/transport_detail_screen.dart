import 'package:equipe_app/domain/policies/transport_review.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppPetIcon, AppScreenTips, AppTourTarget;
import '../../../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/external_actions.dart';
import '../../core/formatters.dart';
import '../../core/location_sharing.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import 'transport_actions.dart';
import 'widgets/location_sharing_card.dart';

class TransportDetailScreen extends StatelessWidget {
  const TransportDetailScreen({super.key, required this.transportId});
  final String transportId;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.driverTransport,
    tips: TeamTips.driverTransport,
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
    final transport = controller.transports
        .where(
          (item) =>
              item.id == transportId &&
              item.tenantId == controller.activeTenantId,
        )
        .firstOrNull;
    if (transport == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transporte')),
        body: const Center(
          child: Text('Transporte indisponível. Atualize a lista.'),
        ),
      );
    }
    final goingToDestination =
        transport.status == TransportStatus.petCollected ||
        transport.status == TransportStatus.inTransit ||
        transport.status == TransportStatus.delivered;
    final needsReview = transportNeedsReview(
      transport.scheduledAt,
      transport.status == TransportStatus.assigned ? 'ASSIGNED' : '',
    );
    final readOnly = transport.status.finished || controller.readOnly;
    final location = controller.location;
    return Scaffold(
      appBar: AppBar(title: Text('Transporte')),
      body: PageBody(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (needsReview)
              const Text(
                'Atrasado — precisa de revisão. Solicite ao atendente a remarcação ou o cancelamento antes de iniciar.',
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transport.type.label.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${activeTenant.tenantName} · ${time(transport.displayScheduledAt)}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                TransportStatusChip(status: transport.status),
              ],
            ),
            if (location != null && routeStatuses.contains(transport.status))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: AppTourTarget(
                  id: TipTargets.driverLocation,
                  child: LocationSharingCard(sharing: location),
                ),
              ),
            const SizedBox(height: 24),
            const SectionTitle('Pets'),
            if (transport.type == TransportType.returnTrip)
              const Text(
                'O retorno só é liberado quando todos os pets deste transporte terminarem o atendimento. Atualize para consultar a situação.',
              ),
            ...transport.pets.map(
              (pet) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 8,
                    ),
                    leading: AppPetIcon(
                      icon: pet.breedIcon,
                      size: 44,
                      semanticLabel: pet.breed,
                    ),
                    title: Text(
                      pet.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '${pet.breed} · Porte ${pet.size.toLowerCase()}${pet.serviceStatus == null ? '' : '\nAtendimento: ${pet.serviceStatus!.label}'}',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppTourTarget(
              id: TipTargets.driverAddress,
              child: AddressCard(
                title: 'Origem',
                address: transport.origin,
                highlighted: !goingToDestination && !readOnly,
                onRoute: !goingToDestination && !transport.status.finished
                    ? () => _openMap(context, transport.origin)
                    : null,
                onCall: !transport.status.finished
                    ? () => _call(context, transport.origin.phone)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            AddressCard(
              title: 'Destino',
              address: transport.destination,
              highlighted: goingToDestination && !readOnly,
              onRoute: goingToDestination && !transport.status.finished
                  ? () => _openMap(context, transport.destination)
                  : null,
              onCall: goingToDestination && !transport.status.finished
                  ? () => _call(context, transport.destination.phone)
                  : null,
            ),
            if (transport.notes.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionTitle('Observações de transporte'),
              AppContentCard(
                padding: const EdgeInsets.all(18),
                child: Text(transport.notes),
              ),
            ],
            if (transport.collectedAt != null ||
                transport.deliveredAt != null) ...[
              const SizedBox(height: 22),
              const SectionTitle('Horários registrados'),
              AppContentCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    if (transport.collectedAt != null)
                      _Info(
                        'Coletado',
                        '${date(transport.collectedAt!)} às ${time(transport.collectedAt!)}',
                      ),
                    if (transport.deliveredAt != null)
                      _Info(
                        'Entregue',
                        '${date(transport.deliveredAt!)} às ${time(transport.deliveredAt!)}',
                        last: true,
                      ),
                  ],
                ),
              ),
            ],
            if (transport.incidents.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionTitle('Ocorrências'),
              ...transport.incidents.map(
                (incident) => Card(
                  child: ListTile(
                    title: Text(incident.type),
                    subtitle: Text(
                      '${incident.description.isEmpty ? 'Sem observação adicional.' : incident.description}\n${date(incident.createdAt)} às ${time(incident.createdAt)}',
                    ),
                  ),
                ),
              ),
            ],
            if (transport.collectionChecks != null ||
                transport.deliveryChecks.isNotEmpty) ...[
              const SectionTitle('Conferência dos pets'),
              for (var i = 0; i < transport.pets.length; i++)
                Text(_petCheckLabel(transport, i)),
            ],
            if (transport.assignmentHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionTitle('Trocas de responsável'),
              for (final entry in transport.assignmentHistory)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(entry),
                ),
            ],
            const SizedBox(height: 26),
            AppTourTarget(
              id: TipTargets.driverAction,
              child: TransportPrimaryAction(
                status: transport.status,
                busy: controller.busy,
                enabled: !controller.readOnly && !needsReview,
                onPressed: () => performPrimaryAction(context, transport.id),
              ),
            ),
            if (!readOnly) ...[
              const SizedBox(height: 8),
              AppTourTarget(
                id: TipTargets.driverIncident,
                child: OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => showIncidentSheet(context, transport.id),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Registrar ocorrência'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(BuildContext context, TransportAddress address) async {
    if (!await openTransportRoute(address) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum aplicativo de navegação disponível.'),
        ),
      );
    }
  }

  Future<void> _call(BuildContext context, String phone) async {
    if (!await callPhone(phone) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o discador.')),
      );
    }
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: AppTextStyles.captionMuted),
        ),
        Expanded(child: Text(value, style: AppTextStyles.value)),
      ],
    ),
  );
}

String _petCheckLabel(TransportJob transport, int index) {
  final id = transport.petIdAt(index);
  final collection = transport.collectionChecks
      ?.where((c) => c.petId == id)
      .firstOrNull;
  final delivery = transport.deliveryChecks
      .where((c) => c.petId == id)
      .firstOrNull;
  final collectionLabel = collection == null
      ? 'sem registro'
      : collection.confirmed
      ? 'confirmada'
      : 'não coletado';
  final deliveryLabel = collection?.confirmed == false
      ? 'não se aplica'
      : delivery?.confirmed == true
      ? 'confirmada'
      : 'pendente';
  return '${transport.pets[index].name}: coleta $collectionLabel · entrega $deliveryLabel';
}
