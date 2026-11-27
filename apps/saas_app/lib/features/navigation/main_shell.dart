import 'dart:async';

import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppDimensions, AppRefreshBody, AppOfflineBanner;

import '../../data/push_device.dart';
import '../../state/app_scope.dart';
import '../auth/login_screen.dart';
import '../auth/email_code_screen.dart';

import '../audit/audit_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../more/more_screen.dart';
import '../subscriptions/billing_requests_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../support/support_requests_screen.dart';
import '../tenants/tenants_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushDevice.opened.addListener(_tapped);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tapped());
  }

  @override
  void dispose() {
    PushDevice.opened.removeListener(_tapped);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A tapped push opens what it announced: the subscription requests or
  /// the support request.
  void _tapped() {
    if (!mounted) return;
    final data = PushDevice.take(
      (data) => data['kind'] == 'BILLING_REQUEST' || data['kind'] == 'SUPPORT',
    );
    if (data == null) return;
    final support = data['supportRequestId'];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => data['kind'] == 'BILLING_REQUEST'
            ? const BillingRequestsScreen()
            : support == null
            ? const SupportRequestsScreen()
            : SupportRequestDetailScreen(requestId: support),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final controller = AppScope.of(context);
    await controller.refresh();
    if (mounted && controller.admin == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  late int _index = widget.initialIndex;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) {
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
    if (controller.requiresEmailCode) return const EmailCodeScreen();
    final pages = [
      DashboardScreen(onSelectTab: (value) => setState(() => _index = value)),
      const TenantsScreen(),
      const SubscriptionsScreen(),
      const AuditScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: AppRefreshBody(
          onRefresh: _refresh,
          child: Column(
            children: [
              if (controller.readOnly || controller.offline)
                AppOfflineBanner(
                  message: controller.readOnly
                      ? controller.refreshWarning ??
                            controller.connectionProblem.readOnlyBanner
                      : '${controller.connectionProblem.title}. '
                            'Puxe para baixo para tentar novamente.',
                ),
              if (controller.error != null && !controller.offline)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(controller.error!),
                ),
              if (controller.cacheWarning != null &&
                  controller.refreshWarning == null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(controller.cacheWarning!),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDimensions.platformPageWidth,
                    ),
                    child: IndexedStack(index: _index, children: pages),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Início',
          ),
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Empresas',
          ),
          // Counters of what waits for the platform (A1-s).
          NavigationDestination(
            icon: _counted(
              controller.billingQueue.subscriptionCount,
              const Icon(Icons.credit_card_outlined),
            ),
            selectedIcon: _counted(
              controller.billingQueue.subscriptionCount,
              const Icon(Icons.credit_card_rounded),
            ),
            label: 'Assinaturas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'Auditoria',
          ),
          NavigationDestination(
            icon: _counted(
              controller.supportWaitingCount,
              const Icon(Icons.grid_view_outlined),
            ),
            selectedIcon: _counted(
              controller.supportWaitingCount,
              const Icon(Icons.grid_view_rounded),
            ),
            label: 'Mais',
          ),
        ],
      ),
    );
  }

  static Widget _counted(int count, Widget icon) => Badge(
    isLabelVisible: count > 0,
    label: Text(count > 99 ? '99+' : '$count'),
    child: icon,
  );
}
