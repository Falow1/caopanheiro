import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRefreshBody;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppPetIcon, AppScreenTips, AppTourTarget;
import '../../../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppRadii, AppTextStyles, showAppConfirmation;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../domain/policies/service_actions.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import 'observation_sheet.dart';

class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.proAppointment,
    tips: TeamTips.proAppointment,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final appointment = controller.appointments
        .where((item) => item.id == appointmentId)
        .firstOrNull;
    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Atendimento')),
        body: const Center(
          child: Text('Atendimento indisponível. Atualize a agenda.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Atendimento')),
      body: AppRefreshBody(
        onRefresh: () async {
          await controller.refresh();
        },
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPetIcon(
                    icon: appointment.pet.breedIcon,
                    size: 68,
                    semanticLabel: appointment.pet.breed,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.pet.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${appointment.pet.breed} · ${appointment.pet.size}',
                        ),
                        const SizedBox(height: 8),
                        StatusBadge(status: appointment.status),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppContentCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _InfoLine(
                      icon: Icons.schedule_rounded,
                      label: 'Horário',
                      value:
                          '${formatDate(appointment.displayStartsAt)} às ${formatTime(appointment.displayStartsAt)}',
                    ),
                    _InfoLine(
                      icon: Icons.timer_outlined,
                      label: 'Duração estimada',
                      value: '${appointment.totalDuration} minutos',
                    ),
                    _InfoLine(
                      icon: Icons.person_outline_rounded,
                      label: 'Tutor',
                      value: appointment.tutorName,
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const SectionTitle('Serviços'),
              ...appointment.services.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: AppRadii.r12,
                        ),
                        child: const Icon(
                          Icons.content_cut_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        service.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text('${service.durationMinutes} minutos'),
                    ),
                  ),
                ),
              ),
              if (appointment.tutorNotes.isNotEmpty) ...[
                const SectionTitle('Orientações do tutor'),
                AppContentCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(appointment.tutorNotes),
                ),
                const SizedBox(height: 16),
              ],
              if (appointment.notes.isNotEmpty) ...[
                const SectionTitle('Orientações da equipe'),
                AppContentCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(appointment.notes),
                ),
                const SizedBox(height: 16),
              ],
              if (appointment.pet.notes.isNotEmpty) ...[
                const SizedBox(height: 22),
                const SectionTitle('Cuidados importantes'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.noticeSurface,
                    borderRadius: AppRadii.r16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 11),
                      Expanded(child: Text(appointment.pet.notes)),
                    ],
                  ),
                ),
              ],
              if (appointment.observations.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionTitle('Observações do atendimento'),
                ...appointment.observations.map(
                  (observation) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: AppContentCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(observation.text),
                          const SizedBox(height: 7),
                          Text(
                            formatTime(observation.createdAt),
                            style: AppTextStyles.metadata,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              if (controller.error != null)
                Text(controller.error!, style: AppTextStyles.danger),
              if (controller.integrated)
                const Text('O início e a conclusão são individuais por pet.'),
              AppTourTarget(
                id: TipTargets.proActions,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _actions(context, controller, appointment),
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
    Appointment appointment,
  ) {
    if (controller.readOnly) {
      return [
        const Text(
          'Consulta offline. Conecte-se e atualize para registrar alterações.',
        ),
      ];
    }
    final actions = serviceActionsFor(appointment.status);
    if (actions == ServiceActions.startService) {
      return [
        FilledButton.icon(
          onPressed: controller.busy
              ? null
              : () => controller.updateStatus(
                  appointment.id,
                  AppointmentStatus.inProgress,
                ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Iniciar atendimento'),
        ),
      ];
    }
    if (actions == ServiceActions.inProgress) {
      return [
        OutlinedButton.icon(
          onPressed: controller.busy
              ? null
              : () => _addObservation(context, controller, appointment.id),
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Adicionar observação'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: controller.busy
              ? null
              : () => _confirmFinish(context, controller, appointment),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Finalizar atendimento'),
        ),
      ];
    }
    return const [];
  }

  Future<void> _addObservation(
    BuildContext context,
    AppController controller,
    String appointmentId,
  ) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => const ObservationSheet(),
    );
    if (text != null) {
      await controller.addObservation(appointmentId, text);
    }
  }

  Future<void> _confirmFinish(
    BuildContext context,
    AppController controller,
    Appointment appointment,
  ) async {
    final confirmed = await showAppConfirmation(
      context,
      title: 'Finalizar atendimento?',
      message:
          'Confirmar conclusão do atendimento de ${appointment.pet.name}? Os outros pets mantêm sua situação atual.',
      confirmLabel: 'Finalizar atendimento',
      icon: Icons.task_alt_rounded,
    );
    if (confirmed) {
      await controller.updateStatus(
        appointment.id,
        AppointmentStatus.completed,
      );
    }
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
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
  Widget build(BuildContext context) {
    return Padding(
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
}
