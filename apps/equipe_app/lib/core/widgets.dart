export 'team_layout.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppBrand,
        AppDimensions,
        AppFormPage,
        AppMessageState,
        AppPageBody,
        AppSectionHeader,
        AppSpacing;

export '../features/agenda/widgets/appointment_status_badge.dart'
    show StatusBadge;

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

class Brand extends StatelessWidget {
  const Brand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => AppBrand.team(compact: compact);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
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

class FormScaffold extends StatelessWidget {
  const FormScaffold({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppFormPage(
    title: title,
    maxWidth: AppDimensions.teamFormWidth,
    child: child,
  );
}

class PermissionNotice extends StatelessWidget {
  const PermissionNotice({
    super.key,
    this.message = 'Seu perfil não possui permissão para esta ação.',
  });
  final String message;

  @override
  Widget build(BuildContext context) => AppMessageState(
    icon: Icons.lock_outline_rounded,
    title: 'Acesso restrito',
    message: message,
    center: true,
    padding: const EdgeInsets.all(32),
    iconSize: 48,
    titleGap: 14,
    messageGap: 6,
    mainAxisSize: MainAxisSize.min,
    titleTextAlign: null,
  );
}
