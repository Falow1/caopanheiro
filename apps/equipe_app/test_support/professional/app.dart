import 'package:flutter/material.dart';

import 'package:equipe_app/modules/professional/core/app_theme.dart';
import 'package:equipe_app/modules/professional/features/auth/login_screen.dart';
import 'package:equipe_app/modules/professional/features/navigation/main_shell.dart';
import 'package:equipe_app/modules/professional/state/app_controller.dart';
import 'package:equipe_app/modules/professional/state/app_scope.dart';

class ProfessionalApp extends StatelessWidget {
  const ProfessionalApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Profissional Cãopanheiro',
        theme: AppTheme.light,
        home: controller.professional == null
            ? const LoginScreen()
            : const MainShell(),
      ),
    );
  }
}
