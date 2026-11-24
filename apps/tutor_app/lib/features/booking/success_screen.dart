import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/appointment.dart';
import '../appointments/appointment_detail_screen.dart';
import '../navigation/main_shell.dart';
import '../navigation/tutor_shell_scope.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key, required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.primary,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Agendamento\nconfirmado!',
                    style: Theme.of(context).textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${appointment.petNames} · ${formatDateTime(appointment.displayStartsAt)}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 38),
                  FilledButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        settings: bookingDoneRoute,
                        builder: (_) => AppointmentDetailScreen(
                          appointmentId: appointment.id,
                          fromSuccess: true,
                        ),
                      ),
                    ),
                    child: const Text('Ver agendamento'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => backToHome(context),
                    child: const Text('Voltar ao início'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
