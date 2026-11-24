import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppActionCard, AppRadii;

import '../../../domain/models.dart';
import '../../../core/app_theme.dart';
import '../../../core/formatters.dart';
import 'appointment_status_badge.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    this.showDate = false,
  });

  final Appointment appointment;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    return AppActionCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: AppRadii.r15,
            ),
            child: Column(
              children: [
                Text(
                  showDate
                      ? appointment.displayStartsAt.day.toString()
                      : formatTime(appointment.displayStartsAt),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: showDate ? 20 : 14,
                  ),
                ),
                if (showDate)
                  Text(
                    formatTime(appointment.displayStartsAt),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
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
                  appointment.pet.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  appointment.services
                      .map((service) => service.name)
                      .join(' + '),
                ),
                const SizedBox(height: 9),
                StatusBadge(status: appointment.status),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}
