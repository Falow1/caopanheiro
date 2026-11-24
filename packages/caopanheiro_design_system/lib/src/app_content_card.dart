import 'package:flutter/material.dart';

/// Original informational card shell. Content and actions belong to the app.
class AppContentCard extends StatelessWidget {
  const AppContentCard({super.key, required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

/// Original text-only empty state, without adding an icon or an action.
class AppEmptyLabel extends StatelessWidget {
  const AppEmptyLabel(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}
