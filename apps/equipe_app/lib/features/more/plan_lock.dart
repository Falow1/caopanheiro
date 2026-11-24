import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import 'plan_screen.dart';

/// Explains a feature the plan of the petshop does not include (A1). The
/// server refuses the commands anyway; this only says where it is offered.
/// [openAnyway] keeps reading what already exists, as past transports.
Future<void> showPlanLocked(
  BuildContext context, {
  required String title,
  required String message,
  VoidCallback? openAnyway,
}) async {
  final controller = AppScope.of(context);
  final plans =
      controller.companyExtrasAvailable && controller.isPrincipalAccount;
  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.lock_outline_rounded),
      title: Text(title),
      content: Text(
        plans ? message : '$message Fale com o gestor principal do petshop.',
      ),
      actions: [
        if (openAnyway != null)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'open'),
            child: const Text('Abrir mesmo assim'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Fechar'),
        ),
        if (plans)
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'plans'),
            child: const Text('Ver planos'),
          ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (choice == 'open') openAnyway?.call();
  if (choice == 'plans') {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlanScreen()),
    );
  }
}

const tutorAppLockedTitle = 'Disponível no Essencial e no Completo';
const tutorAppLockedMessage =
    'Link fixo, QR Code e o app do tutor ficam nos planos pagos. No Grátis, a equipe cadastra e agenda os clientes.';
const transportLockedTitle = 'Disponível no Completo';
const transportLockedMessage =
    'Transporte com entregador e o acompanhamento pelo tutor ficam no plano Completo. Os transportes já registrados continuam para consulta.';
