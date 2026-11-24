export '../../../core/team_layout.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppBrand, AppDimensions, AppPageBody, AppSectionHeader, AppSpacing;

export '../features/appointments/widgets/appointment_status_badge.dart'
    show StatusBadge;
export '../features/appointments/widgets/appointment_card.dart'
    show AppointmentCard;

class Brand extends StatelessWidget {
  const Brand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => AppBrand.professional(compact: compact);
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.padding = AppSpacing.page,
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => AppPageBody(
    padding: padding,
    maxWidth: AppDimensions.teamPageWidth,
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) =>
      AppSectionHeader(title: title, expandTitle: false);
}
