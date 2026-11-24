import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppConfirmTone, showAppConfirmation;
import 'package:flutter/material.dart';

/// Confirmations required by SECURITY for actions with consequences. Closing
/// the dialog or using Back counts as cancelling. A [confirmStyle] marks a
/// destructive action, shown with the danger tone of the shared dialog.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  ButtonStyle? confirmStyle,
}) => showAppConfirmation(
  context,
  title: title,
  message: message,
  confirmLabel: confirmLabel,
  cancelLabel: cancelLabel,
  tone: confirmStyle == null ? AppConfirmTone.neutral : AppConfirmTone.danger,
);

Future<bool> confirmSignOut(BuildContext context) => confirmAction(
  context,
  title: 'Sair da conta?',
  message: 'Será necessário entrar novamente para usar o aplicativo.',
  confirmLabel: 'Sair',
);

Future<bool> confirmDiscardChanges(BuildContext context) => confirmAction(
  context,
  title: 'Descartar alterações?',
  message: 'As alterações feitas nesta tela não foram salvas e serão perdidas.',
  cancelLabel: 'Continuar editando',
  confirmLabel: 'Descartar',
);

/// Wraps a form so leaving with unsaved changes asks first.
class DiscardGuard extends StatelessWidget {
  const DiscardGuard({super.key, required this.dirty, required this.child});
  final bool dirty;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      if (await confirmDiscardChanges(context) && context.mounted) {
        Navigator.pop(context);
      }
    },
    child: child,
  );
}
