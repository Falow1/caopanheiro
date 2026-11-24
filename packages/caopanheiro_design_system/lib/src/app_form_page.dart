import 'package:flutter/material.dart';

import 'app_dimensions.dart';
import 'app_spacing.dart';

/// Original form scaffold: no extra Form, validation, SafeArea or navigation.
class AppFormPage extends StatelessWidget {
  const AppFormPage({
    super.key,
    required this.title,
    required this.child,
    this.maxWidth = AppDimensions.platformFormWidth,
  });

  final String title;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(padding: AppSpacing.form, child: child),
      ),
    ),
  );
}
