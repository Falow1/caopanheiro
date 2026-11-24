import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppEmptyLabel, AppRadii, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import '../appointments/appointment_detail_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static final DateTime _today = DateTime(2026, 9, 20);

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.proToday,
    tips: TeamTips.proToday,
    ready: !AppScope.of(context).busy,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final professional = controller.professional;
    // The outgoing route can rebuild after signOut clears the session.
    if (professional == null) return const SizedBox.shrink();
    final today = controller.integrated ? DateTime.now() : _today;
    final appointments = controller.appointments.where((item) {
      return item.displayStartsAt.year == today.year &&
          item.displayStartsAt.month == today.month &&
          item.displayStartsAt.day == today.day;
    }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final remaining = appointments.where((item) {
      return item.status != AppointmentStatus.completed &&
          item.status != AppointmentStatus.cancelled &&
          item.status != AppointmentStatus.noShow;
    }).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: TeamLayout.header,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hoje',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
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
                              'Olá, ${professional.name.split(' ').first}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(formatFriendlyDate(today)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: AppRadii.r99,
                        ),
                        child: Text(
                          '$remaining restantes',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navy, AppColors.primary],
                  ),
                  borderRadius: AppRadii.r22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SEU DIA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${appointments.length} atendimentos programados',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Tudo que você precisa, em ordem de horário.',
                      style: AppTextStyles.onDarkSecondary,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: appointments.isEmpty
                  ? const AppEmptyLabel('Nenhum atendimento hoje.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      itemCount: appointments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 11),
                      itemBuilder: (_, index) => AppTourTarget(
                        id: TipTargets.proTodayCard,
                        child: AppointmentCard(
                          appointment: appointments[index],
                          onTap: () => _open(context, appointments[index]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Appointment appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(appointmentId: appointment.id),
      ),
    );
  }
}
