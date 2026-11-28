import 'package:caopanheiro_core/caopanheiro_core.dart'
    show FirebaseEnvironment, buildFirebaseEnvironment;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppCodeVerificationPage;
import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';
import 'login_screen.dart';

class EmailCodeScreen extends StatelessWidget {
  const EmailCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    Future<bool> proceed(Future<bool> Function() confirm) async {
      final confirmed = await confirm();
      if (confirmed && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (_) => false,
        );
      }
      return confirmed;
    }

    return AppCodeVerificationPage(
      destination: controller.admin?.email ?? 'seu e-mail',
      busy: controller.busy,
      error: controller.error,
      demoNote: controller.canSkipEmailCode
          ? 'Ambiente de demonstração com dados fictícios. Para testar o SaaS com esta conta, toque em Continuar sem código.'
          : buildFirebaseEnvironment == FirebaseEnvironment.local
          ? 'Ambiente local: nenhum e-mail real é enviado. O código fica na coleção platformEmailOutbox do painel do banco.'
          : 'Versão de demonstração: nenhum e-mail é enviado. O código fica na coleção platformEmailOutbox, no console do Firebase. A administração só abre com o código.',
      onRequest: controller.requestEmailCode,
      onVerify: (code) => proceed(() => controller.verifyEmailCode(code)),
      onSkip: controller.canSkipEmailCode
          ? () async {
              await proceed(controller.skipDemoEmailCode);
            }
          : null,
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
