import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppBrand, AppPawMark, AppTextStyles;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../navigation/tutor_wide_layout.dart';

/// Entry pages (Login, Criar conta, Acesso ao petshop) on wide windows: the
/// welcome on the dark green of the brand at the left, the page at the
/// right. Narrow windows show only the page, as before. The page keeps its
/// place in the tree, so it survives a window that crosses the breakpoint.
class AuthWelcomeLayout extends StatelessWidget {
  const AuthWelcomeLayout({
    super.key,
    required this.title,
    this.message,
    this.note,
    required this.child,
  });
  final String title;
  final String? message;

  /// Shown at the bottom of the welcome, with the shield.
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.canvas,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tutorWide(context))
          Expanded(
            key: const ValueKey('auth.welcome'),
            child: _Welcome(title: title, message: message, note: note),
          ),
        Expanded(key: const ValueKey('auth.page'), child: child),
      ],
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.title, this.message, this.note});
  final String title;
  final String? message;
  final String? note;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.primaryDark,
    child: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 40, 56, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The Tutor mark, with the name in white on the dark green.
                  const AppBrand(
                    product: '',
                    nameColor: Colors.white,
                    circular: true,
                    mark: Center(child: AppPawMark()),
                  ),
                  const Spacer(),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.displaySmall?.copyWith(color: Colors.white),
                  ),
                  if (message case final message?) ...[
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Text(
                        message,
                        style: AppTextStyles.onDarkSecondary.copyWith(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const Spacer(),
                  if (note case final note?)
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note,
                            style: AppTextStyles.onDarkSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
