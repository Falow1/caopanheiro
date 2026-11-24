import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTipsScope;

import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/navigation/main_shell.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';

class TutorApp extends StatelessWidget {
  const TutorApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: AppTipsScope(
      store: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tutor Cãopanheiro',
        // The top bar keeps its colour when the content scrolls under it,
        // as on the screens without a bar.
        theme: AppTheme.light.copyWith(
          appBarTheme: AppTheme.light.appBarTheme.copyWith(
            scrolledUnderElevation: 0,
          ),
        ),
        home: controller.tutor == null
            ? const LoginScreen()
            : const MainShell(),
      ),
    ),
  );
}
