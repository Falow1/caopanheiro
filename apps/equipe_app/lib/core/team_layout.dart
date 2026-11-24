import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTourTarget;
import 'screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppDimensions, AppOfflineBanner, AppSpacing;

/// Shared chrome for the four roles in the Equipe application.
abstract final class TeamLayout {
  static const header = AppSpacing.teamHeader;
  static const page = AppSpacing.teamPage;
  static const list = AppSpacing.teamList;
  static const width = AppDimensions.teamPageWidth;
}

class TeamNavigationBar extends StatelessWidget {
  const TeamNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) => AppTourTarget(
    id: TipTargets.nav,
    child: NavigationBar(
      height: AppDimensions.teamNavigationHeight,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
    ),
  );
}

/// Offline notice in the page column: same width and left edge as the
/// page titles, on phones and on wide screens.
class TeamOfflineBanner extends StatelessWidget {
  const TeamOfflineBanner({super.key, this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: TeamLayout.width),
      child: AppOfflineBanner(
        margin: EdgeInsets.fromLTRB(
          TeamLayout.page.left,
          12,
          TeamLayout.page.right,
          0,
        ),
        message: message ?? AppOfflineBanner.defaultMessage,
      ),
    ),
  );
}
