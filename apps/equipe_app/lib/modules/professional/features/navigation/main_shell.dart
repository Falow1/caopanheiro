import '../../../../core/team_layout.dart';
import '../../../../state/workforce_scope.dart';
import '../../../../features/more/confirm_sign_out.dart' show askSignOut;
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRefreshBody;

import '../../state/app_scope.dart';
import '../auth/login_screen.dart';

import '../agenda/agenda_screen.dart';
import '../profile/profile_screen.dart';
import '../today/today_screen.dart';

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
    if (workforce != null && workforce.function?.name != 'professional') return;
    await controller.refresh();
    if (mounted &&
        workforce != null &&
        workforce.function?.name != 'professional') {
      return;
    }
    if (mounted && controller.professional == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.professional == null) {
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
    if (controller.integrated && controller.companyId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Escolha a empresa'),
          actions: [
            IconButton(
              tooltip: 'Sair',
              onPressed: () async {
                if (!await askSignOut(context) || !context.mounted) return;
                controller.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: ListView(
          children: [
            if (controller.error != null && !controller.offline)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(controller.error!),
              ),
            ...controller.companies.map(
              (company) => ListTile(
                title: Text(company.name),
                onTap: controller.busy
                    ? null
                    : () async {
                        await controller.selectCompany(company.id);
                        if (mounted && controller.professional == null) {
                          await _refresh();
                        }
                      },
              ),
            ),
          ],
        ),
      );
    }
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
              if (controller.error != null && !controller.offline)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(controller.error!),
                ),
              if (controller.cacheWarning != null)
                Text(controller.cacheWarning!),
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
                        children: tipTabs(_index, [
                          const TodayScreen(),
                          const AgendaScreen(),
                          ProfileScreen(
                            companyActions:
                                controller.integrated &&
                                    WorkforceScope.maybeOf(context) == null &&
                                    controller.companies.length > 1
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Empresa'),
                                        subtitle: Text(
                                          controller.companies
                                                  .where(
                                                    (company) =>
                                                        company.id ==
                                                        controller.companyId,
                                                  )
                                                  .firstOrNull
                                                  ?.name ??
                                              'Empresa',
                                        ),
                                        trailing:
                                            controller.companies.length > 1
                                            ? PopupMenuButton<String>(
                                                tooltip: 'Trocar empresa',
                                                onSelected: (id) {
                                                  controller.selectCompany(id);
                                                },
                                                itemBuilder: (_) => controller
                                                    .companies
                                                    .map(
                                                      (company) =>
                                                          PopupMenuItem(
                                                            value: company.id,
                                                            child: Text(
                                                              company.name,
                                                            ),
                                                          ),
                                                    )
                                                    .toList(),
                                              )
                                            : null,
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ]),
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
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Agenda',
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
