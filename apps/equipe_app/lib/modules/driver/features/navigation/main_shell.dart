import '../../../../core/team_layout.dart';
import '../../../../state/workforce_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRefreshBody;

import '../auth/login_screen.dart';
import '../tenant/tenant_selection_screen.dart';

import '../../state/app_scope.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../today/today_screen.dart';
import '../transports/transports_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final controller = AppScope.of(context);
    final workforce = WorkforceScope.maybeOf(context);
    if (workforce != null && workforce.function?.name != 'driver') return;
    await controller.refresh();
    if (mounted && workforce != null && workforce.function?.name != 'driver') {
      return;
    }
    if (!mounted) return;
    if (controller.profile == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } else if (controller.activeTenantId == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TenantSelectionScreen()),
        (_) => false,
      );
    }
  }

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.profile == null) {
      if (WorkforceScope.maybeOf(context) != null) {
        return const SizedBox.shrink();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      });
      return const SizedBox.shrink();
    }
    final pages = [
      TodayScreen(onViewAll: () => setState(() => _index = 1)),
      const TransportsScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: AppRefreshBody(
          onRefresh: _refresh,
          child: Column(
            children: [
              if (controller.readOnly || controller.offline)
                TeamOfflineBanner(
                  message: controller.readOnly
                      ? controller.connectionProblem.readOnlyBanner
                      : '${controller.connectionProblem.title}. '
                            'Puxe para baixo para tentar novamente.',
                ),
              if (controller.cacheWarning != null)
                Text(controller.cacheWarning!),
              if (controller.error != null && !controller.offline)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(controller.error!),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: TeamLayout.width,
                    ),
                    child: SizedBox.expand(
                      child: IndexedStack(
                        index: _index,
                        children: tipTabs(_index, pages),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: TeamNavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Hoje',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Transportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
