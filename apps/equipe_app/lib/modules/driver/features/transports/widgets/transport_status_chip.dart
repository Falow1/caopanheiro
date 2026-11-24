import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppStatusBadge;

import '../../../domain/models.dart';
import '../../../core/app_theme.dart';

class TransportStatusChip extends StatelessWidget {
  const TransportStatusChip({super.key, required this.status});
  final TransportStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      TransportStatus.assigned => (
        AppColors.pendingSurface,
        AppColors.pendingInk,
      ),
      TransportStatus.goingToOrigin => (
        AppColors.receivedSurface,
        AppColors.violet,
      ),
      TransportStatus.petCollected => (
        AppColors.progressSurface,
        AppColors.progressInk,
      ),
      TransportStatus.inTransit => (AppColors.mint, AppColors.primary),
      TransportStatus.delivered => (
        AppColors.completedSurface,
        AppColors.completedInk,
      ),
      TransportStatus.cancelled => (
        AppColors.cancelledSurface,
        AppColors.cancelledInk,
      ),
    };
    return AppStatusBadge(
      label: status.label,
      background: background,
      foreground: foreground,
    );
  }
}
