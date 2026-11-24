import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppBrand,
        AppDimensions,
        AppMessageState,
        AppPageBody,
        AppSectionHeader,
        AppSpacing;

export '../../features/appointments/widgets/appointment_status_chip.dart'
    show StatusChip;
export '../../features/booking/widgets/step_indicator.dart' show StepIndicator;

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.showName = true});
  final bool showName;

  @override
  Widget build(BuildContext context) => AppBrand.tutor(compact: !showName);
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.padding = AppSpacing.tutorPage,
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => AppPageBody(
    padding: padding,
    maxWidth: AppDimensions.tutorPageWidth,
    child: child,
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => AppSectionHeader(
    title: title,
    action: action == null
        ? null
        : TextButton(onPressed: onAction, child: Text(action!)),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) =>
      AppMessageState(icon: icon, title: title, message: message);
}
