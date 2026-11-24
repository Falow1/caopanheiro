import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppConfirmTone, showAppConfirmation;
import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../auth/login_screen.dart';

/// Voluntary exit: states the consequence and offers Cancelar. Automatic
/// session endings (revoked or expired access) do not pass through here.
Future<void> confirmSignOut(BuildContext context) async {
  final confirmed = await showAppConfirmation(
    context,
    title: 'Sair da administração?',
    message:
        'A sessão administrativa será encerrada neste aparelho. Para voltar, será preciso entrar de novo e informar o código enviado por e-mail.',
    confirmLabel: 'Sair',
    tone: AppConfirmTone.danger,
  );
  if (!confirmed || !context.mounted) return;
  AppScope.of(context).signOut();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
