import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppStatusBadge, AppTypography;

import '../../../domain/models/appointment.dart';
import '../../../core/theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      AppointmentStatus.requested => (
        AppColors.tutorPendingSurface,
        AppColors.pendingInk,
      ),
      AppointmentStatus.confirmed => (
        AppColors.tutorConfirmedSurface,
        AppColors.primaryDark,
      ),
      AppointmentStatus.petReceived => (
        AppColors.tutorReceivedSurface,
        AppColors.tutorReceivedInk,
      ),
      AppointmentStatus.inProgress => (
        AppColors.tutorProgressSurface,
        AppColors.tutorProgressInk,
      ),
      AppointmentStatus.completed => (
        AppColors.tutorCompletedSurface,
        AppColors.tutorCompletedInk,
      ),
      AppointmentStatus.cancelled => (
        AppColors.tutorCancelledSurface,
        AppColors.tutorCancelledInk,
      ),
      AppointmentStatus.noShow => (
        AppColors.inactiveSurface,
        AppColors.inactiveInk,
      ),
    };
    return AppStatusBadge(
      label: status.label,
      background: background,
      foreground: foreground,
      fontSize: AppTypography.tutorBadgeSize,
      radius: AppRadii.tutorBadge,
    );
  }
}
