import 'state/workforce_controller.dart';
import 'state/workforce_scope.dart';
import 'modules/professional/state/app_scope.dart' as pro;
import 'modules/driver/state/app_scope.dart' as delivery;
import 'features/navigation/unified_shell.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_theme.dart';

import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppDimensions, AppTipsScope;

import 'features/auth/login_screen.dart';
import 'features/auth/access_paused_screen.dart';
import 'features/auth/staff_link_screen.dart';
import 'domain/repositories/staff_link_repository.dart';
import 'features/auth/company_selection_screen.dart';
import 'features/navigation/main_shell.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';

class InternalApp extends StatelessWidget {
  const InternalApp({super.key, required this.controller, this.workforce});
  final AppController controller;
  final WorkforceController? workforce;

  @override
  Widget build(BuildContext context) {
    Widget child = AppScope(
      controller: controller,
      child: AppTipsScope(
        store: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateRoute: (settings) {
            final link = StaffLink.fromRoute(settings.name);
            return link == null
                ? null
                : MaterialPageRoute(
                    settings: const RouteSettings(name: '/convite'),
                    builder: (_) => StaffLinkScreen(link: link),
                  );
          },
          onUnknownRoute: (_) =>
              MaterialPageRoute(builder: (_) => const LoginScreen()),
          title: 'Equipe Cãopanheiro',
          // Portuguese also for what Flutter writes itself: the date picker
          // (typed as day/month/year), the 24-hour clock, the copy and paste
          // menu and the labels read by the screen reader.
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light.copyWith(
            appBarTheme: AppTheme.light.appBarTheme.copyWith(
              centerTitle: false,
              titleSpacing: AppDimensions.teamTitleSpacing,
              toolbarHeight: AppDimensions.teamToolbarHeight,
            ),
          ),
          home: controller.pausedAccess.isNotEmpty && controller.user == null
              ? const AccessPausedScreen()
              : controller.catalogOnly && controller.user != null
              ? controller.unified
                    ? const UnifiedShell()
                    : const MainShell(initialIndex: 2)
              : controller.catalogOnly && controller.companies.isNotEmpty
              ? const CompanySelectionScreen()
              : const LoginScreen(),
        ),
      ),
    );
    final session = workforce;
    if (session != null) {
      child = WorkforceScope(
        controller: session,
        child: pro.AppScope(
          controller: session.professional,
          child: delivery.AppScope(controller: session.driver, child: child),
        ),
      );
    }
    return child;
  }
}
