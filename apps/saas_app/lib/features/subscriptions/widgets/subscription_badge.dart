import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppStatusBadge;

import '../../../domain/models.dart';
import '../../../core/app_theme.dart';

class SubscriptionBadge extends StatelessWidget {
  const SubscriptionBadge({super.key, required this.status});
  final SubscriptionStatus status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SubscriptionStatus.active => AppColors.primary,
      SubscriptionStatus.trial => AppColors.violet,
      SubscriptionStatus.pending => AppColors.warning,
      SubscriptionStatus.expired ||
      SubscriptionStatus.cancelled => AppColors.danger,
    };
    return AppStatusBadge(
      label: status.label,
      background: color.withValues(alpha: .12),
      foreground: color,
    );
  }
}
