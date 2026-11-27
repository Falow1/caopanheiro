import 'package:caopanheiro_core/caopanheiro_core.dart' show displayPhone;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRefreshBody;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppOfflineBanner;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppPetIcon, AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppButtonStyles,
        AppConfirmTone,
        AppContentCard,
        AppRadii,
        AppTextStyles,
        showAppConfirmation;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../domain/policies/appointment_actions.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import 'appointment_edit_screen.dart';
import 'transport_form_screen.dart';
import 'transport_creation_gate.dart';
import 'transport_management_screen.dart';

class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});
  final String appointmentId;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.appointment,
    tips: TeamTips.appointment,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.user == null) return const SizedBox.shrink();
    final matches = controller.appointments.where(
      (value) => value.id == appointmentId,
    );
    if (matches.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Agendamento indisponível. Atualize a agenda.'),
        ),
      );
    }
    final item = matches.first;
    return Scaffold(
      appBar: AppBar(title: Text('Agendamento')),
      body: AppRefreshBody(
        onRefresh: () async {
          await controller.refreshAgenda();
        },
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.petNames,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  AppTourTarget(
                    id: TipTargets.appointmentStatus,
                    child: StatusBadge(status: item.status),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppContentCard(
                padding: const EdgeInsets.all(19),
                child: Column(
                  children: [
                    _Line(
                      icon: Icons.person_outline_rounded,
                      label: 'Tutor',
                      value: item.customer.name,
                    ),
                    _Line(
                      icon: Icons.phone_outlined,
                      label: 'Contato',
                      value: displayPhone(item.customer.phone),
                    ),
                    _Line(
                      icon: Icons.calendar_today_outlined,
                      label: 'Data e horário',
                      value:
                          '${date(item.displayStartsAt)} às ${time(item.displayStartsAt)}',
                    ),
                    // With pets of different professionals at the same time, the
                    // booking is shorter than the summed time of the services.
                    _Line(
                      icon: Icons.schedule_rounded,
                      label: item.reservedMinutes == item.duration
                          ? 'Duração'
                          : 'Duração somada dos serviços',
                      value: '${item.duration} minutos',
                    ),
                    if (item.reservedMinutes != item.duration)
                      _Line(
                        icon: Icons.timelapse_rounded,
                        label: 'Tempo previsto da reserva',
                        value: '${item.reservedMinutes} minutos',
                      ),
                    _Line(
                      icon: Icons.badge_outlined,
                      label: 'Profissional',
                      value: item.professionals ?? 'Ainda não definido',
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (controller.catalogOnly &&
                  controller.user!.canManage('TRANSPORT') &&
                  ![
                    AppointmentStatus.cancelled,
                    AppointmentStatus.noShow,
                  ].contains(item.status))
                TransportCreationGate(
                  child: OutlinedButton.icon(
                    onPressed: controller.catalogOffline
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TransportFormScreen(appointmentId: item.id),
                            ),
                          ),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Agendar transporte'),
                  ),
                ),
              const SizedBox(height: 10),
              AppTourTarget(
                id: TipTargets.appointmentTransport,
                child: OutlinedButton.icon(
                  onPressed:
                      controller.catalogOffline ||
                          !controller.user!.canManage('TRANSPORT')
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TransportManagementScreen(
                              appointmentId: item.id,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.route_outlined),
                  // Centered like the button above, even on two lines.
                  label: const Text(
                    'Gerenciar transportes',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const SectionTitle('Pets e serviços'),
              AppTourTarget(
                id: TipTargets.appointmentPets,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...item.items.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppContentCard(
                          padding: const EdgeInsets.all(17),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppPetIcon(
                                icon: entry.pet.breedIcon,
                                size: 44,
                                semanticLabel: entry.pet.breed,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.pet.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    // The professional of this pet and the start.
                                    if (entry.professional case final name?)
                                      Text(
                                        entry.companyStartsAt == null
                                            ? name
                                            : '$name · ${time(entry.companyStartsAt!)}',
                                        style: AppTextStyles.caption,
                                      ),
                                    if (controller.catalogOnly) ...[
                                      Text(
                                        'Situação: ${(entry.execution?.status ?? item.status).label}',
                                      ),
                                      if (!controller.catalogOffline &&
                                          controller.user!.canRunService &&
                                          [
                                            AppointmentStatus.petReceived,
                                            AppointmentStatus.inProgress,
                                          ].contains(
                                            entry.execution?.status ??
                                                item.status,
                                          ))
                                        TextButton(
                                          onPressed: controller.busy
                                              ? null
                                              : () => _confirmPetAction(
                                                  context,
                                                  controller,
                                                  item.id,
                                                  entry,
                                                ),
                                          child: Text(
                                            (entry.execution?.status ??
                                                        item.status) ==
                                                    AppointmentStatus
                                                        .petReceived
                                                ? 'Iniciar este pet'
                                                : 'Finalizar este pet',
                                          ),
                                        ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.services
                                          .map((service) => service.name)
                                          .join(' · '),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                money(entry.price),
                                style: AppTextStyles.emphasis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Valor total', style: AppTextStyles.strong),
                  Text(
                    money(item.price),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              if (item.tutorNotes.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionTitle('Orientações do tutor'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.noticeSurface,
                    borderRadius: AppRadii.r16,
                  ),
                  child: Text(item.tutorNotes),
                ),
              ],
              if (item.observations.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionTitle('Observações do profissional'),
                for (final note in item.observations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${item.items.where((entry) => entry.pet.id == note.petId).firstOrNull?.pet.name ?? 'Pet'}: ${note.text}',
                    ),
                  ),
                const Text(
                  'O tutor também vê estas observações no aplicativo.',
                  style: AppTextStyles.captionMuted,
                ),
              ],
              if (item.notes.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionTitle('Observações'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: AppRadii.r16,
                  ),
                  child: Text(item.notes),
                ),
              ],
              const SizedBox(height: 28),
              AppTourTarget(
                id: TipTargets.appointmentActions,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _actions(context, controller, item),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    AppController controller,
    Appointment item,
  ) {
    if (controller.catalogOffline) {
      return [
        const AppOfflineBanner(
          message: 'Consulta offline · alterações exigem conexão.',
        ),
      ];
    }
    if (controller.user?.canManage('APPOINTMENTS') != true) {
      return [
        const Text(
          'Seu acesso permite consultar os atendimentos. Alterações exigem permissão de agenda.',
        ),
      ];
    }
    final widgets = <Widget>[];
    if (controller.error != null) widgets.add(Text(controller.error!));
    final actions = appointmentActionsFor(item.status, controller.user);
    if (actions == AppointmentActions.confirmed) {
      widgets.add(
        FilledButton.icon(
          onPressed: controller.busy
              ? null
              : () => _confirmStatus(
                  context,
                  controller,
                  item,
                  AppointmentStatus.petReceived,
                ),
          icon: const Icon(Icons.pets_rounded),
          // One pet or all of them, as the appointment has.
          label: Text(
            item.items.map((entry) => entry.pet.id).toSet().length > 1
                ? 'Registrar recebimento de todos os pets'
                : 'Registrar recebimento do pet',
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
      widgets.add(
        OutlinedButton.icon(
          onPressed: controller.busy
              ? null
              : () => _confirmNoShow(context, controller, item.id),
          icon: const Icon(Icons.person_off_outlined),
          label: const Text('Não compareceu'),
        ),
      );
      widgets.add(const SizedBox(height: 10));
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AppointmentEditScreen(appointmentId: item.id),
            ),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar agendamento'),
        ),
      );
      widgets.add(const SizedBox(height: 10));
      widgets.add(
        TextButton(
          style: AppButtonStyles.dangerText,
          onPressed: () => _confirmCancel(context, controller, item.id),
          child: const Text('Cancelar agendamento'),
        ),
      );
    } else if (!controller.catalogOnly &&
        actions == AppointmentActions.startService) {
      widgets.add(
        FilledButton.icon(
          onPressed: controller.busy
              ? null
              : () => controller.updateStatus(
                  item.id,
                  AppointmentStatus.inProgress,
                ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Iniciar atendimento'),
        ),
      );
    } else if (!controller.catalogOnly &&
        actions == AppointmentActions.finishService) {
      widgets.add(
        FilledButton.icon(
          onPressed: controller.busy
              ? null
              : () => _confirmStatus(
                  context,
                  controller,
                  item,
                  AppointmentStatus.completed,
                ),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Finalizar atendimento'),
        ),
      );
    }
    return widgets;
  }

  /// Receiving and finishing the whole appointment have no way back
  /// (scheduling.js transitions), so each names the pets and the consequence
  /// first. Starting the service is immediate, at the user's request.
  Future<void> _confirmStatus(
    BuildContext context,
    AppController controller,
    Appointment item,
    AppointmentStatus status,
  ) async {
    final pets = item.items.map((entry) => entry.pet.name).toSet().join(', ');
    final (title, message, action) = switch (status) {
      AppointmentStatus.petReceived => (
        'Registrar o recebimento de $pets?',
        'A partir de agora o petshop fica responsável pelos pets deste agendamento. Ele não volta para Confirmado, mas ainda pode ser cancelado.',
        'Registrar recebimento',
      ),
      _ => (
        'Finalizar o atendimento de $pets?',
        'O atendimento de todos os pets deste agendamento será concluído e não poderá ser reaberto.',
        'Finalizar atendimento',
      ),
    };
    final confirmed = await showAppConfirmation(
      context,
      title: title,
      message: message,
      confirmLabel: action,
    );
    if (confirmed) await controller.updateStatus(item.id, status);
  }

  Future<void> _confirmPetAction(
    BuildContext context,
    AppController controller,
    String id,
    AppointmentItem entry,
  ) async {
    final start =
        (entry.execution?.status ??
            AppScope.of(
              context,
            ).appointments.firstWhere((a) => a.id == id).status) ==
        AppointmentStatus.petReceived;
    // Starting one pet is immediate; finishing it still asks first.
    if (start) {
      await controller.updatePetStatus(
        id,
        entry.pet.id,
        AppointmentStatus.inProgress,
      );
      return;
    }
    final confirmed = await showAppConfirmation(
      context,
      title: 'Finalizar atendimento de ${entry.pet.name}?',
      message:
          'Esta ação altera somente este pet. O agendamento será concluído quando todos terminarem.',
      confirmLabel: 'Confirmar',
    );
    if (confirmed) {
      await controller.updatePetStatus(
        id,
        entry.pet.id,
        AppointmentStatus.completed,
      );
    }
  }

  Future<void> _confirmNoShow(
    BuildContext context,
    AppController controller,
    String id,
  ) async {
    final confirmed = await showAppConfirmation(
      context,
      title: 'Registrar que não compareceu?',
      message:
          'O agendamento será encerrado como não comparecimento e os transportes ligados a ele serão cancelados. Esta ação não pode ser desfeita.',
      confirmLabel: 'Não compareceu',
      cancelLabel: 'Voltar',
      tone: AppConfirmTone.danger,
    );
    if (confirmed) {
      await controller.updateStatus(id, AppointmentStatus.noShow);
    }
  }

  Future<void> _confirmCancel(
    BuildContext context,
    AppController controller,
    String id,
  ) async {
    final confirmed = await showAppConfirmation(
      context,
      title: 'Cancelar agendamento?',
      message:
          'O horário voltará a ficar disponível e o registro será mantido no histórico.',
      confirmLabel: 'Cancelar agendamento',
      cancelLabel: 'Voltar',
      tone: AppConfirmTone.danger,
    );
    if (confirmed) {
      await controller.updateStatus(id, AppointmentStatus.cancelled);
    }
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 15),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.metadata),
              Text(value, style: AppTextStyles.value),
            ],
          ),
        ),
      ],
    ),
  );
}
