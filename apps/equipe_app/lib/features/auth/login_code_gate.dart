import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppCodeVerificationPage;
import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import 'login_screen.dart';

/// Shows the standard code page after a new login, then [child]. In this
/// demonstration the code can be skipped: the server does not require it.
class LoginCodeGate extends StatefulWidget {
  const LoginCodeGate({super.key, required this.email, required this.child});
  final String email;
  final Widget child;
  @override
  State<LoginCodeGate> createState() => _LoginCodeGateState();
}

class _LoginCodeGateState extends State<LoginCodeGate> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (_done || !controller.loginCodeAvailable) return widget.child;
    return AppCodeVerificationPage(
      destination: widget.email.isEmpty ? 'seu e-mail' : widget.email,
      busy: controller.busy,
      error: controller.error,
      demoNote:
          'Versão de demonstração: o e-mail com o código ainda não é enviado. Toque em Continuar sem código para entrar.',
      onRequest: controller.requestLoginCode,
      onVerify: (code) async {
        final verified = await controller.verifyLoginCode(code);
        if (verified && mounted) setState(() => _done = true);
        return verified;
      },
      onSkip: () {
        controller.clearError();
        setState(() => _done = true);
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
