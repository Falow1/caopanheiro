import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/email_code_screen.dart';
import 'features/navigation/main_shell.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';

class SaasAdminApp extends StatelessWidget {
  const SaasAdminApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SaaS Cãopanheiro',
      // Portuguese also for what Flutter writes itself: the date picker of
      // Renovar até (typed as day/month/year), the copy and paste menu and
      // the labels read by the screen reader.
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      home: controller.admin == null
          ? const LoginScreen()
          : controller.requiresEmailCode
          ? const EmailCodeScreen()
          : const MainShell(),
    ),
  );
}
