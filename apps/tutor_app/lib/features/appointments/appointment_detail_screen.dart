import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRefreshBody, AppWindowClass, appWindowClassOf;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppButtonStyles, AppContentCard, AppRadii, AppTextStyles;

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../domain/models/appointment.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/service.dart';
import '../../domain/policies/appointment_tracking.dart';
import '../../state/app_scope.dart';
import '../home/read_only_company.dart';
import '../booking/booking_draft.dart';
import '../booking/online_schedule_screen.dart';
import '../booking/transport_options_screen.dart';
import '../navigation/main_shell.dart';
import '../navigation/tutor_shell_scope.dart';
import '../navigation/tutor_wide_layout.dart';
import '../transport/transport_tracking_card.dart';

class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.appointmentId,
    this.fromSuccess = false,
  });
  final String appointmentId;
  final bool fromSuccess;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.appointment,
    tips: tutorTips(context, TutorTips.appointment),
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final appointment = controller.appointments
        .where((item) => item.id == appointmentId)
        .firstOrNull;
    if (appointment == null) {
      return const Scaffold(
        body: Center(
          child: Text('Agendamento indisponível. Atualize a agenda.'),
        ),
      );
    }
    final cancellable = canCancelAppointment(appointment.status);
    // Left on wide windows: what was booked.
    final summary = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              appointment.petNames,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          StatusChip(status: appointment.status),
        ],
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: AppRadii.r22,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 30,
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(appointment.displayStartsAt),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                Text(
                  '${formatTime(appointment.displayStartsAt)} · ${appointment.totalDuration} min',
                  style: AppTextStyles.onDarkSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      const SectionHeader(title: 'Serviços'),
      ...appointment.items.map(
        (item) => AppContentCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.petName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(item.serviceNames.join(' · ')),
              const SizedBox(height: 6),
              StatusChip(status: item.execution?.status ?? appointment.status),
              for (final note in appointment.observations.where(
                (observation) => observation.petId == item.petId,
              )) ...[
                const SizedBox(height: 12),
                const Text(
                  'Observação do profissional',
                  style: AppTextStyles.captionMuted,
                ),
                const SizedBox(height: 2),
                Text(note.text),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.durationMinutes} min',
                    style: AppTextStyles.caption,
                  ),
                  Text(formatMoney(item.price), style: AppTextStyles.emphasis),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total dos serviços', style: AppTextStyles.strong),
          Text(
            formatMoney(appointment.totalPrice),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
      if (appointment.tutorNotes.isNotEmpty) ...[
        const SizedBox(height: 24),
        const SectionHeader(title: 'Suas orientações para a equipe'),
        AppContentCard(
          padding: const EdgeInsets.all(18),
          child: Text(appointment.tutorNotes),
        ),
      ],
    ];
    // Right on wide windows: how it is going and what can be done.
    final follow = <Widget>[
      // Also asked when the tutor requested nothing: the team may
      // have scheduled pickup or return directly.
      TransportTrackingCard(
        key: ValueKey('transport-${appointment.id}'),
        appointmentId: appointment.id,
        servicesPrice: appointment.totalPrice,
        hideWhenEmpty: appointment.transport == null,
      ),
      const SectionHeader(title: 'Histórico de status'),
      ...appointment.history.asMap().entries.map(
        (entry) => _TimelineEvent(
          event: entry.value,
          isLast: entry.key == appointment.history.length - 1,
        ),
      ),
      if (cancellable && controller.companyReadOnly) ...[
        const SizedBox(height: 24),
        const ReadOnlyCompanyBanner(bottom: 0),
      ],
      if (cancellable && controller.integrated && !controller.companyReadOnly) ...[
        const SizedBox(height: 24),
        AppTourTarget(
          id: TipTargets.appointmentReschedule,
          child: OutlinedButton.icon(
            onPressed: controller.busy
                ? null
                : controller.companyBookingPaused
                ? () => showBookingByPhone(context)
                : () => _reschedule(context, appointment),
            icon: const Icon(Icons.event_repeat_rounded),
            label: const Text('Remarcar'),
          ),
        ),
        const SizedBox(height: 10),
        AppTourTarget(
          id: TipTargets.appointmentTransport,
          child: OutlinedButton.icon(
            onPressed: controller.busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TransportOptionsScreen(
                        draft: BookingDraft(
                          pets: const [],
                          companyId: controller.companyId,
                        ),
                        appointmentId: appointment.id,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Solicitar transporte'),
          ),
        ),
      ],
      if (cancellable && !controller.companyReadOnly) ...[
        const SizedBox(height: 10),
        AppTourTarget(
          id: TipTargets.appointmentCancel,
          child: OutlinedButton(
            style: AppButtonStyles.dangerOutlinedTutor,
            onPressed: controller.busy
                ? null
                : () => _askCancel(context, appointment),
            child: const Text('Cancelar agendamento'),
          ),
        ),
      ],
    ];
    return Scaffold(
      appBar: AppBar(
        leading: fromSuccess
            ? IconButton(
                onPressed: () => backToHome(context),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text('Agendamento'),
        actions: [
          // Pulling the page down needs a touch screen.
          if (appWindowClassOf(context) == AppWindowClass.expanded)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TutorRefreshButton(
                onRefresh: controller.refresh,
                loading: controller.busy,
              ),
            ),
        ],
      ),
      body: AppRefreshBody(
        onRefresh: () async {
          await controller.refresh();
        },
        child: TutorPageBody(
          child: TutorTwoColumns(left: summary, right: follow, gap: 30),
        ),
      ),
    );
  }

  /// Moves the same pets and services to another time. Prices follow the
  /// current catalogue and are confirmed again by the server.
  void _reschedule(BuildContext context, Appointment appointment) {
    final controller = AppScope.of(context);
    void refuse(String message) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    final pets = <Pet>[];
    final selected = <String, Set<PetService>>{};
    for (final item in appointment.items) {
      final pet = controller.pets.where((p) => p.id == item.petId).firstOrNull;
      final services = [
        for (final id in item.serviceIds)
          controller.services.where((s) => s.id == id).firstOrNull,
      ];
      if (pet == null || services.isEmpty || services.contains(null)) {
        refuse(
          'Um pet ou serviço deste agendamento não está mais disponível. Fale com o petshop para remarcar.',
        );
        return;
      }
      pets.add(pet);
      selected[pet.id] = services.whereType<PetService>().toSet();
    }
    final draft = BookingDraft(
      pets: pets,
      companyId: controller.companyId,
      selectedServices: selected,
      rescheduleOf: appointment.id,
    )..tutorNotes = appointment.tutorNotes;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: bookingRoute,
        builder: (_) => OnlineScheduleScreen(draft: draft),
      ),
    );
  }

  Future<void> _askCancel(BuildContext context, Appointment appointment) async {
    final transport = appointment.transport != null
        ? '\n\nOs pedidos de coleta e retorno deste agendamento também serão cancelados. Se algum pet já estiver em transporte, a equipe precisa ser contatada.'
        : '';
    final confirmed = await confirmAction(
      context,
      title: 'Cancelar agendamento?',
      message:
          '${appointment.petNames} · ${formatDateTime(appointment.displayStartsAt)}\n\nO horário será liberado para outra pessoa e o registro continuará no seu histórico.$transport',
      cancelLabel: 'Voltar',
      confirmLabel: 'Cancelar agendamento',
      confirmStyle: AppButtonStyles.dangerFilled,
    );
    if (confirmed && context.mounted) {
      await AppScope.of(context).cancelAppointment(appointmentId);
    }
  }
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({required this.event, required this.isLast});
  final StatusEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: AppColors.line)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.status.label, style: AppTextStyles.value),
                const SizedBox(height: 2),
                Text(formatDateTime(event.at), style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
