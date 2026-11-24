import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppConfirmTone, showAppConfirmation;
import '../../state/app_scope.dart';
import '../auth/login_screen.dart';

/// Asks before ending the session; true only when the person confirms.
/// Also used by the professional and driver profiles, which have their own state.
Future<bool> askSignOut(BuildContext context) => showAppConfirmation(
  context,
  title: 'Sair da conta?',
  message: 'Você precisará entrar novamente para acessar o aplicativo.',
  confirmLabel: 'Sair',
  tone: AppConfirmTone.danger,
);

Future<void> confirmSignOut(BuildContext context) async {
  final controller = AppScope.of(context);
  if (controller.busy ||
      (controller.user == null && controller.companies.isEmpty)) {
    return;
  }
  final revision = controller.sessionRevision;
  final confirmed = await askSignOut(context);
  if (!confirmed ||
      !context.mounted ||
      controller.busy ||
      (controller.user == null && controller.companies.isEmpty) ||
      revision != controller.sessionRevision) {
    return;
  }
  controller.signOut();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
