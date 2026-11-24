import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// Section title with an optional existing action. No navigation is added.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.expandTitle = true,
  });

  final String title;
  final Widget? action;
  final bool expandTitle;

  @override
  Widget build(BuildContext context) {
    final heading = Text(title, style: Theme.of(context).textTheme.titleLarge);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
      child: expandTitle || action != null
          ? Row(
              children: [
                Expanded(child: heading),
                if (action != null) action!,
              ],
            )
          : heading,
    );
  }
}
