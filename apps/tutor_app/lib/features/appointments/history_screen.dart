import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles;

import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/models/appointment.dart';
import '../../domain/policies/appointment_tracking.dart';
import '../../state/app_scope.dart';
import '../navigation/tutor_wide_layout.dart';
import 'appointment_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = appointmentHistory(AppScope.of(context).appointments);
    // A line per visit where the columns fit; cards otherwise.
    final rows = tutorTwoColumns(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: TutorPageBody(
        child: items.isEmpty
            ? const EmptyState(
                icon: Icons.history_rounded,
                title: 'Nenhum atendimento ainda',
                message: 'Seus atendimentos anteriores aparecerão aqui.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Atendimentos anteriores',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Valores e serviços preservados como no dia do agendamento.',
                  ),
                  const SizedBox(height: 24),
                  ...items.map(
                    (appointment) => Padding(
                      padding: EdgeInsets.only(bottom: rows ? 10 : 12),
                      child: Card(
                        margin: rows ? EdgeInsets.zero : null,
                        child: InkWell(
                          borderRadius: AppRadii.r22,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AppointmentDetailScreen(
                                appointmentId: appointment.id,
                              ),
                            ),
                          ),
                          child: rows
                              ? _WideRow(appointment: appointment)
                              : _NarrowCard(appointment: appointment),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The phone and narrow windows: pets and situation on top, then the date and the services.
class _NarrowCard extends StatelessWidget {
  const _NarrowCard({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                appointment.petNames,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            StatusChip(status: appointment.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${formatDate(appointment.displayStartsAt)} · ${appointment.items.expand((item) => item.serviceNames).join(', ')}',
        ),
        if (appointment.transport != null) ...[
          const SizedBox(height: 6),
          Text(
            'Com transporte · taxa ${formatMoney(appointment.transportFeeCents / 100)} · toque para ver a situação',
            style: AppTextStyles.captionMuted,
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${appointment.totalDuration} min',
              style: AppTextStyles.captionMuted,
            ),
            Text(
              formatMoney(appointment.totalPrice),
              style: AppTextStyles.emphasis,
            ),
          ],
        ),
      ],
    ),
  );
}

/// Wide content areas: one line per visit, with the same columns on every line
/// (date, pets, services, situation, duration and value).
class _WideRow extends StatelessWidget {
  const _WideRow({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            formatDate(appointment.displayStartsAt),
            style: AppTextStyles.value,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            appointment.petNames,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.items
                    .expand((item) => item.serviceNames)
                    .join(', '),
              ),
              if (appointment.transport != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Com transporte · taxa ${formatMoney(appointment.transportFeeCents / 100)} · clique para ver a situação',
                  style: AppTextStyles.captionMuted,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 150,
          child: Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(status: appointment.status),
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
            '${appointment.totalDuration} min',
            style: AppTextStyles.captionMuted,
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(
            formatMoney(appointment.totalPrice),
            textAlign: TextAlign.right,
            style: AppTextStyles.emphasis,
          ),
        ),
      ],
    ),
  );
}
