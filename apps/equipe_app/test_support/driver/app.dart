import 'package:flutter/material.dart';

import 'package:equipe_app/modules/driver/core/app_theme.dart';
import 'package:equipe_app/modules/driver/features/auth/login_screen.dart';
import 'package:equipe_app/modules/driver/features/navigation/main_shell.dart';
import 'package:equipe_app/modules/driver/features/tenant/tenant_selection_screen.dart';
import 'package:equipe_app/modules/driver/state/app_controller.dart';
import 'package:equipe_app/modules/driver/state/app_scope.dart';

class DriverApp extends StatelessWidget {
  const DriverApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Entregador Cãopanheiro',
      theme: AppTheme.light,
      home: controller.profile == null
          ? const LoginScreen()
          : controller.activeTenantId == null
          ? const TenantSelectionScreen()
          : const MainShell(),
    ),
  );
}
