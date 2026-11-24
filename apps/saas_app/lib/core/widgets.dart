import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppBrand,
        AppDimensions,
        AppFormPage,
        AppPageBody,
        AppSectionHeader,
        AppSpacing;

export '../features/tenants/widgets/tenant_badge.dart' show TenantBadge;
export '../features/subscriptions/widgets/subscription_badge.dart'
    show SubscriptionBadge;
export '../features/tenants/widgets/tenant_context_header.dart'
    show ContextHeader;

class Brand extends StatelessWidget {
  const Brand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => AppBrand.platform(compact: compact);
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
    maxWidth: AppDimensions.platformPageWidth,
    child: child,
  );
}

/// Shared heading for the five primary SaaS tabs. Insets belong to the page.
class SaasPageTitle extends StatelessWidget {
  const SaasPageTitle(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(subtitle!),
            ],
          ],
        ),
      ),
      if (action != null) ...[const SizedBox(width: 12), action!],
    ],
  );
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

class FormPage extends StatelessWidget {
  const FormPage({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppFormPage(
    title: title,
    maxWidth: AppDimensions.platformFormWidth,
    child: child,
  );
}
