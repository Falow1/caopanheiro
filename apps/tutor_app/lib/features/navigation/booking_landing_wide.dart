import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTextStyles, AppTourTarget;
import 'package:flutter/material.dart';

import '../../core/screen_tips.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/policies/appointment_tracking.dart';
import '../../state/app_scope.dart';
import '../appointments/appointment_detail_screen.dart';
import '../home/home_screen.dart';
import 'tutor_wide_layout.dart';

/// The steps of a booking, for "Como funciona".
const _steps = [
  ('Pets', 'Escolha quem vem. Dá para marcar mais de um pet.'),
  ('Serviços', 'Escolha o que cada pet precisa, com o preço e a duração.'),
  ('Horário', 'Escolha o dia, o horário e, se quiser, o profissional.'),
  ('Revisão', 'Confira tudo e confirme. O horário é conferido de novo.'),
];

/// Agendar on wide windows: the header of the other tabs, with Atualizar and
/// Novo agendamento of the usual size in the line of the title, the next
/// appointments at the left and how the booking goes at the right. The
/// phone keeps its page.
class BookingLandingWide extends StatelessWidget {
  const BookingLandingWide({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final upcoming = upcomingAppointments(AppScope.of(context).appointments);
    return Scaffold(
      body: SafeArea(
        child: TutorPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Um cuidado novo\ncomeça aqui.',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Escolha os pets, os serviços e o melhor horário. Você revisa tudo antes de confirmar.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const TutorRefreshButton(),
                  const SizedBox(width: 10),
                  AppTourTarget(
                    id: TipTargets.bookingStart,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: onStart,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Novo agendamento'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TutorTwoColumns(
                left: [
                  const SectionHeader(title: 'Próximos agendamentos'),
                  if (upcoming.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Text('Você não tem agendamentos futuros.'),
                      ),
                    )
                  else
                    for (final appointment in upcoming.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: UpcomingAppointmentCard(
                          appointment: appointment,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AppointmentDetailScreen(
                                appointmentId: appointment.id,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
                right: const [
                  SectionHeader(title: 'Como funciona'),
                  _HowItWorks(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The steps, numbered, and the transport, which depends on the petshop.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, (title, text)) in _steps.indexed) ...[
            if (index > 0) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.mint,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(text, style: AppTextStyles.captionMuted),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Se o petshop oferece transporte, antes da revisão você pode pedir a busca e a volta dos pets.',
            style: AppTextStyles.captionMuted,
          ),
        ],
      ),
    ),
  );
}
