import 'package:caopanheiro_core/caopanheiro_core.dart'
    show FirebaseEnvironment, buildFirebaseEnvironment;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppCodeVerificationPage;
import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';
import 'login_screen.dart';

/// The standard code page. The SaaS server requires the code for the
/// administration, so this app offers no way to skip it.
class EmailCodeScreen extends StatelessWidget {
  const EmailCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppCodeVerificationPage(
      destination: controller.admin?.email ?? 'seu e-mail',
      busy: controller.busy,
      error: controller.error,
      demoNote: buildFirebaseEnvironment == FirebaseEnvironment.local
          ? 'Ambiente local: nenhum e-mail real é enviado. O código fica na coleção platformEmailOutbox do painel do banco.'
          : 'Versão de demonstração: nenhum e-mail é enviado. O código fica na coleção platformEmailOutbox, no console do Firebase. A administração só abre com o código.',
      onRequest: controller.requestEmailCode,
      onVerify: (code) async {
        final verified = await controller.verifyEmailCode(code);
        if (verified && context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()),
            (_) => false,
          );
        }
        return verified;
      },
      onSignOut: () {
        controller.signOut();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      },
    );
  }
}
