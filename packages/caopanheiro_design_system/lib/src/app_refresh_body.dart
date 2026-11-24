import 'package:flutter/material.dart';

/// Refreshes existing queries by pulling, including short/empty nested pages.
class AppRefreshBody extends StatelessWidget {
  const AppRefreshBody({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(
      physics: AlwaysScrollableScrollPhysics(
        parent: ScrollConfiguration.of(context).getScrollPhysics(context),
      ),
    ),
    child: RefreshIndicator(
      onRefresh: onRefresh,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.vertical,
      child: CustomScrollView(
        primary: false,
        physics: AlwaysScrollableScrollPhysics(
          parent: ScrollConfiguration.of(context).getScrollPhysics(context),
        ),
        slivers: [SliverFillRemaining(hasScrollBody: true, child: child)],
      ),
    ),
  );
}
