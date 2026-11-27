import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppCodeVerificationPage;
import 'package:flutter/material.dart';

import '../../state/app_scope.dart';

/// The standard code page after a new login. In this demonstration the code
/// can be skipped: the server does not require it.
class LoginCodeScreen extends StatelessWidget {
  const LoginCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppCodeVerificationPage(
      destination: controller.tutor?.email.isNotEmpty == true
          ? controller.tutor!.email
          : 'seu e-mail',
      busy: controller.busy,
      error: controller.error,
      demoNote:
          'Versão de demonstração: o e-mail com o código ainda não é enviado. Toque em Continuar sem código para entrar.',
      onRequest: controller.requestLoginCode,
      onVerify: controller.verifyLoginCode,
      onSkip: controller.skipLoginCode,
      onSignOut: controller.signOut,
    );
  }
}
