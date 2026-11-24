import 'package:flutter/material.dart';

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
      theme: AppTheme.light,
      home: controller.admin == null
          ? const LoginScreen()
          : controller.requiresEmailCode
          ? const EmailCodeScreen()
          : const MainShell(),
    ),
  );
}
