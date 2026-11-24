import '../agenda/transport_review_notice.dart';
import '../../core/team_layout.dart';
import '../../core/screen_tips.dart';
import 'package:flutter/material.dart';

import 'billing_notice.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRefreshBody;

import '../agenda/agenda_screen.dart';
import '../booking/customer_selection_screen.dart';
import '../customers/customers_screen.dart';
import '../more/more_screen.dart';
import '../services/services_screen.dart';
import '../../state/app_scope.dart';
import '../../state/app_controller.dart';
import '../auth/login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppLifecycleListener? _lifecycle;
  bool _loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (controller.catalogOnly) {
      _lifecycle ??= AppLifecycleListener(onResume: () => _refresh(controller));
      if (!_loaded) {
        _loaded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadCompany(controller);
        });
      }
    }
  }

  Future<void> _loadCompany(AppController controller) async {
    if (controller.user == null || controller.busy) return;
    await controller.refreshAgenda();
    if (controller.user != null) await controller.refreshCustomers();
  }

  Future<void> _refresh(AppController controller) async {
    if (controller.user == null || controller.busy) return;
    await controller.refreshServices();
    if (controller.user != null) await controller.refreshAgenda();
    if (controller.user != null) {
      await controller.refreshCustomers();
    }
    if (mounted && controller.user == null && controller.companies.isEmpty) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  late int _index = widget.initialIndex;
  void _newAppointment() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CustomerSelectionScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final pages = [
      AgendaScreen(onNew: _newAppointment),
      const CustomersScreen(),
      const ServicesScreen(),
      const MoreScreen(),
    ];
    return BillingNoticeHost(
      child: Scaffold(
        body: SafeArea(
          child: AppRefreshBody(
            onRefresh: () => _refresh(AppScope.of(context)),
            child: Column(
              children: [
                const TransportReviewNotice(),
                if (controller.catalogOffline || controller.offline)
                  TeamOfflineBanner(
                    message: controller.connectionProblem.readOnlyBanner,
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
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Clientes',
            ),
            NavigationDestination(
              icon: Icon(Icons.content_cut_outlined),
              selectedIcon: Icon(Icons.content_cut_rounded),
              label: 'Serviços',
            ),
            NavigationDestination(
              icon: Icon(
                controller.user?.isManager == true
                    ? Icons.grid_view_outlined
                    : Icons.person_outline_rounded,
              ),
              selectedIcon: Icon(
                controller.user?.isManager == true
                    ? Icons.grid_view_rounded
                    : Icons.person_rounded,
              ),
              label: controller.user?.isManager == true ? 'Mais' : 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
