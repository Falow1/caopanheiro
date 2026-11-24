import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppStatusBadge;

import '../../../domain/models.dart';
import '../../../core/app_theme.dart';

class TenantBadge extends StatelessWidget {
  const TenantBadge({super.key, required this.status});
  final TenantStatus status;
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      TenantStatus.active => (AppColors.mint, AppColors.primary),
      TenantStatus.onboarding => (
        AppColors.tenantPendingSurface,
        AppColors.tenantPendingInk,
      ),
      TenantStatus.suspended => (AppColors.cancelledSurface, AppColors.danger),
    };
    return AppStatusBadge(
      label: status.label,
      background: background,
      foreground: foreground,
    );
  }
}
