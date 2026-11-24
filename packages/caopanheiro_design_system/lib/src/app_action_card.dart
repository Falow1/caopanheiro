import 'package:flutter/material.dart';

import 'app_radii.dart';

/// Shared Card/InkWell/Padding shell. Domain content and onTap stay in the app.
class AppActionCard extends StatelessWidget {
  const AppActionCard({
    super.key,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(17),
    this.splashRadius = AppRadii.card,
  });

  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius splashRadius;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: splashRadius,
      child: Padding(padding: padding, child: child),
    ),
  );
}
