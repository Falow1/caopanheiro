import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppStatusBadge;

import '../../../domain/models.dart';
import '../../../core/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final AppointmentStatus status;
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      AppointmentStatus.requested => (
        AppColors.pendingSurface,
        AppColors.pendingInk,
      ),
      AppointmentStatus.confirmed => (AppColors.mint, AppColors.primary),
      AppointmentStatus.petReceived => (
        AppColors.receivedSurface,
        AppColors.violet,
      ),
      AppointmentStatus.inProgress => (
        AppColors.progressSurface,
        AppColors.progressInk,
      ),
      AppointmentStatus.completed => (
        AppColors.completedSurface,
        AppColors.completedInk,
      ),
      AppointmentStatus.cancelled => (
        AppColors.cancelledSurface,
        AppColors.cancelledInk,
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
    );
  }
}
