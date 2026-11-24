import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppColors,
        AppDimensions,
        AppPageBody,
        AppSpacing,
        AppTourTarget,
        AppWindowClass,
        appWindowClassOf;
import 'package:flutter/material.dart';

import '../../core/screen_tips.dart';
import '../../state/app_scope.dart';
import 'tutor_shell_scope.dart';

/// True on windows from 900 of width: the desktop design.
bool tutorWide(BuildContext context) =>
    appWindowClassOf(context) == AppWindowClass.expanded;

/// True when the content area beside the side bar fits two columns.
bool tutorTwoColumns(BuildContext context) =>
    tutorWide(context) &&
    tutorContentWidth(context) >= AppDimensions.tutorTwoColumnWidth;

/// Page of the Tutor: the column of 620 on the phone ([phonePadding]) and up
/// to 1080 on wide windows. The widgets are the same on both, so what is
/// below keeps its state when the window crosses the breakpoint.
class TutorPageBody extends StatelessWidget {
  const TutorPageBody({
    super.key,
    required this.child,
    this.phonePadding = AppSpacing.tutorPage,
  });
  final Widget child;
  final EdgeInsets phonePadding;

  @override
  Widget build(BuildContext context) {
    final wide = tutorWide(context);
    return AppPageBody(
      maxWidth: wide
          ? AppDimensions.tutorDesktopPageWidth
          : AppDimensions.tutorPageWidth,
      padding: wide ? const EdgeInsets.fromLTRB(32, 24, 32, 40) : phonePadding,
      child: child,
    );
  }
}

/// [left] and [right] side by side when the content area fits two columns,
/// one under the other otherwise, [gap] apart. Same blocks in the same order
/// and in the same place of the tree either way, so they keep their state
/// when the window is resized. Tab goes through the whole left column before
/// the right one.
class TutorTwoColumns extends StatelessWidget {
  const TutorTwoColumns({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 3,
    this.rightFlex = 2,
    this.gap = 28,
  });
  final List<Widget> left;
  final List<Widget> right;
  final int leftFlex;
  final int rightFlex;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final two = tutorTwoColumns(context);
    Widget column(List<Widget> children, int flex) => Flexible(
      flex: two ? flex : 0,
      fit: two ? FlexFit.tight : FlexFit.loose,
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    return Flex(
      direction: two ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: two
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: [
        column(left, leftFlex),
        SizedBox(width: two ? 32 : 0, height: two ? 0 : gap),
        column(right, rightFlex),
      ],
    );
  }
}

/// Atualizar in the header of a tab on wide windows, where pulling the page
/// down needs a touch screen. [tipTarget] marks the one the tips of the
/// Início point to; the other tabs leave it unmarked, because the tabs stay
/// mounted side by side and a target id must not repeat.
class TutorRefreshButton extends StatelessWidget {
  const TutorRefreshButton({
    super.key,
    this.tipTarget = false,
    this.label = 'Atualizar',
    this.onRefresh,
    this.loading = false,
  });
  final bool tipTarget;
  final String label;

  /// What a screen refreshes by itself (the transport, the times); null
  /// refreshes the whole account, as pulling the page down does.
  final VoidCallback? onRefresh;

  /// Whether [onRefresh] is still running: the button waits for it.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
      onPressed: onRefresh == null
          ? _account(context)
          : (loading ? null : onRefresh),
      icon: const Icon(Icons.refresh_rounded),
      label: Text(label),
    );
    return tipTarget
        ? AppTourTarget(id: TipTargets.refresh, child: button)
        : button;
  }

  VoidCallback? _account(BuildContext context) {
    final controller = AppScope.of(context);
    final shell = TutorShellScope.maybeOf(context);
    return controller.busy
        ? null
        : () => shell == null ? controller.refresh() : shell.refresh();
  }
}

/// Column of a form: the whole width on the phone, as before, and a central
/// column of 620 on wide windows. Same widgets on both, so the typed text and
/// the scroll survive a window that crosses the breakpoint.
class TutorFormColumn extends StatelessWidget {
  const TutorFormColumn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: tutorWide(context)
            ? AppDimensions.tutorPageWidth
            : double.infinity,
      ),
      child: child,
    ),
  );
}

/// [save] and [cancel] at the end of a form on wide windows: side by side
/// at the right, with the main action last. On the phone they stay in
/// [TutorFormBar].
class TutorFormActions extends StatelessWidget {
  const TutorFormActions({super.key, required this.save, required this.cancel});
  final Widget save;
  final Widget cancel;

  @override
  Widget build(BuildContext context) {
    // The theme makes filled buttons as wide as the column; here it sits
    // beside Cancelar, so it takes the width of its label.
    final theme = FilledButtonTheme.of(context).style;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        cancel,
        const SizedBox(width: 12),
        FilledButtonTheme(
          data: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(140, AppDimensions.filledButtonHeight),
            ).merge(theme),
          ),
          child: save,
        ),
      ],
    );
  }
}

/// A form page: [children] scroll in [TutorFormColumn]. On wide windows
/// [save] and [cancel] end the column, as [TutorFormActions]; on the phone
/// they stay in [TutorFormBar], fixed at the bottom, and the fields scroll
/// behind it. The list keeps its place in the tree on both, so the typed text
/// and the scroll survive a window that crosses the breakpoint.
class TutorFormPage extends StatelessWidget {
  const TutorFormPage({
    super.key,
    required this.padding,
    required this.save,
    required this.cancel,
    required this.children,
  });
  final EdgeInsetsGeometry padding;
  final Widget save;
  final Widget cancel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = tutorWide(context);
    return Column(
      children: [
        Expanded(
          child: TutorFormColumn(
            child: ListView(
              padding: padding,
              children: [
                ...children,
                if (wide) ...[
                  const SizedBox(height: 24),
                  TutorFormActions(save: save, cancel: cancel),
                ],
              ],
            ),
          ),
        ),
        if (!wide) TutorFormBar(save: save, cancel: cancel),
      ],
    );
  }
}

/// [save] over [cancel], fixed at the bottom of the phone forms as the bar of
/// the booking steps: line on top, paper and the safe area. With the keyboard
/// open the page gets shorter and the bar stays above the keyboard.
class TutorFormBar extends StatelessWidget {
  const TutorFormBar({super.key, required this.save, required this.cancel});
  final Widget save;
  final Widget cancel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
    decoration: const BoxDecoration(
      color: AppColors.paper,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          save,
          const SizedBox(height: 4),
          // Cancelar as tall as a touch needs.
          TextButtonTheme(
            data: TextButtonThemeData(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
              ).merge(TextButtonTheme.of(context).style),
            ),
            child: cancel,
          ),
        ],
      ),
    ),
  );
}
