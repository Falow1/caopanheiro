import 'package:flutter/material.dart';

import 'app_dimensions.dart';
import 'app_spacing.dart';

class AppPageBody extends StatelessWidget {
  const AppPageBody({
    super.key,
    required this.child,
    this.padding = AppSpacing.page,
    this.maxWidth = AppDimensions.pageWidth,
  });

  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(padding: padding, child: child),
      ),
    ),
  );
}
