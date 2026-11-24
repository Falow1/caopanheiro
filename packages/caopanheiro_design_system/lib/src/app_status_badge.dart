import 'package:flutter/material.dart';

import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Presentation only: labels, statuses and domain mappings remain in each app.
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.fontSize = AppTypography.badgeSize,
    this.radius = AppRadii.badge,
  });

  final String label;
  final Color background;
  final Color foreground;
  final double fontSize;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.badge,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: fontSize,
        fontWeight: AppTypography.badgeWeight,
      ),
    ),
  );
}
