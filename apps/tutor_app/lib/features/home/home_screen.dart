import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppActionCard,
        AppButtonStyles,
        AppDimensions,
        AppNoticeBell,
        AppNoticesScreen;

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/models/appointment.dart';
import '../../domain/models/pet.dart';
import '../../domain/policies/appointment_tracking.dart';
import '../../state/app_scope.dart';
import '../appointments/appointment_detail_screen.dart';
import '../appointments/history_screen.dart';
import '../navigation/tutor_wide_layout.dart';
import '../pets/pet_form_screen.dart';
import 'read_only_company.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onBook,
    required this.onSelectTab,
  });
  final VoidCallback onBook;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.home,
    tips: tutorTips(context, TutorTips.home),
    ready: !AppScope.of(context).busy,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final upcoming = upcomingAppointments(controller.appointments);
    final wide = tutorWide(context);
    // On wide windows: what comes later and the pets, beside what is now.
    final later = [
      if (upcoming.length > 1) ..._later(context, upcoming),
      if (wide && controller.pets.isNotEmpty)
        ..._pets(context, controller.pets),
    ];
    if (wide && later.isNotEmpty) {
      return Scaffold(
        body: SafeArea(
          child: TutorPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, wide: true),
                const SizedBox(height: 24),
                const ReadOnlyCompanyBanner(),
                TutorTwoColumns(left: _now(context), right: later),
              ],
            ),
          ),
        ),
      );
    }
    // The phone, and wide windows with nothing for a second column: the
    // reading width of 620.
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, wide: wide),
              const SizedBox(height: 28),
              const ReadOnlyCompanyBanner(),
              ..._now(context),
              if (upcoming.length > 1) ...[
                const SizedBox(height: 30),
                ..._later(context, upcoming),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Greeting and notices. On wide windows the brand and the profile are in
  /// the side bar, and Atualizar takes their place.
  Widget _header(BuildContext context, {required bool wide}) {
    final controller = AppScope.of(context);
    return Row(
      children: [
        if (!wide) ...[
          const BrandMark(showName: false),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Olá,', style: TextStyle(color: AppColors.muted)),
              Text(
                controller.tutor?.name.split(' ').first ?? 'Tutor',
                style: wide
                    ? Theme.of(context).textTheme.headlineMedium
                    : Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        if (wide) ...[
          const TutorRefreshButton(tipTarget: true),
          const SizedBox(width: 8),
        ],
        if (controller.noticesAvailable)
          AppNoticeBell(
            unread: controller.noticeCount,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AppNoticesScreen(
                  // The column of the forms, beside the side bar.
                  maxWidth: wide ? AppDimensions.tutorPageWidth : null,
                  cardGap: 12,
                  load: controller.loadNotices,
                  onSeen: controller.markNoticesSeen,
                  onOpen: (notice) {
                    final id = notice.appointmentId;
                    if (id == null ||
                        !controller.appointments.any((item) => item.id == id)) {
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AppointmentDetailScreen(appointmentId: id),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        if (!wide)
          IconButton(
            tooltip: 'Perfil',
            onPressed: () => onSelectTab(3),
            icon: const Icon(Icons.person_outline_rounded),
          ),
      ],
    );
  }

  /// What is happening now, the next appointment and Novo agendamento.
  List<Widget> _now(BuildContext context) {
    final controller = AppScope.of(context);
    final active = activeAppointments(controller.appointments);
    final upcoming = upcomingAppointments(controller.appointments);
    return [
      if (active.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
            borderRadius: AppRadii.r24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.tutorHeroAccent,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'ACONTECENDO AGORA',
                    style: TextStyle(
                      color: AppColors.tutorHeroSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                active.first.petNames,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                active.first.status.label,
                style: AppTextStyles.onDarkSecondary,
              ),
              const SizedBox(height: 18),
              TextButton.icon(
                style: AppButtonStyles.textOnDark,
                onPressed: () => _openDetails(context, active.first),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Acompanhar atendimento'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
      AppTourTarget(
        id: TipTargets.homeHistory,
        child: SectionHeader(
          title: 'Próximo agendamento',
          action: 'Histórico',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
        ),
      ),
      if (upcoming.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Text('Você não tem agendamentos futuros.'),
          ),
        )
      else
        AppTourTarget(
          id: TipTargets.homeNext,
          child: UpcomingAppointmentCard(
            appointment: upcoming.first,
            onTap: () => _openDetails(context, upcoming.first),
          ),
        ),
      // On wide windows the side bar has it, with this tip.
      if (!tutorWide(context)) ...[
        const SizedBox(height: 18),
        AppTourTarget(
          id: TipTargets.homeNew,
          child: FilledButton.icon(
            onPressed: onBook,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo agendamento'),
          ),
        ),
      ],
    ];
  }

  List<Widget> _later(BuildContext context, List<Appointment> upcoming) => [
    const SectionHeader(title: 'Mais adiante'),
    ...upcoming
        .skip(1)
        .take(2)
        .map(
          (appointment) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: UpcomingAppointmentCard(
              appointment: appointment,
              onTap: () => _openDetails(context, appointment),
            ),
          ),
        ),
    const SizedBox(height: 18),
  ];

  /// Wide windows only: a shortcut to each pet, three per line.
  List<Widget> _pets(BuildContext context, List<Pet> pets) => [
    SectionHeader(
      title: 'Seus pets',
      action: 'Ver todos',
      onAction: () => onSelectTab(2),
    ),
    AppTourTarget(
      id: TipTargets.homePets,
      child: LayoutBuilder(
        key: const ValueKey(TipTargets.homePets),
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 24) / 3;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final pet in pets)
                SizedBox(
                  width: width,
                  child: _PetShortcut(pet: pet),
                ),
            ],
          );
        },
      ),
    ),
  ];

  void _openDetails(BuildContext context, Appointment appointment) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AppointmentDetailScreen(appointmentId: appointment.id),
        ),
      );
}

class _PetShortcut extends StatelessWidget {
  const _PetShortcut({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) => AppActionCard(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
    splashRadius: const BorderRadius.all(Radius.circular(22)),
    child: Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(pet.emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          pet.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

/// A coming appointment: the day, the pets, the time and the services and
/// the status. Also in Agendar on wide windows.
class UpcomingAppointmentCard extends StatelessWidget {
  const UpcomingAppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });
  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppActionCard(
    onTap: onTap,
    padding: const EdgeInsets.all(18),
    splashRadius: const BorderRadius.all(Radius.circular(22)),
    child: Row(
      children: [
        Container(
          width: 58,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: AppRadii.r16,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${appointment.displayStartsAt.day}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                formatWeekday(appointment.displayStartsAt).toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.petNames,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${formatTime(appointment.displayStartsAt)} · ${appointment.items.expand((i) => i.serviceNames).join(', ')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 9),
              StatusChip(status: appointment.status),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ],
    ),
  );
}
