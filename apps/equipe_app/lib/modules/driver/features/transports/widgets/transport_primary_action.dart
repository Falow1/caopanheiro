import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppLoadingIndicator, AppRadii, AppTextStyles;
import '../../../domain/models.dart';
import '../../../core/app_theme.dart';

class TransportPrimaryAction extends StatelessWidget {
  const TransportPrimaryAction({
    super.key,
    required this.status,
    required this.onPressed,
    this.busy = false,
    this.enabled = true,
  });
  final TransportStatus status;
  final VoidCallback onPressed;
  final bool busy;
  final bool enabled;

  String get label => switch (status) {
    TransportStatus.assigned => 'Iniciar deslocamento',
    TransportStatus.goingToOrigin => 'Confirmar coleta',
    TransportStatus.petCollected => 'Iniciar transporte',
    TransportStatus.inTransit => 'Confirmar entrega',
    TransportStatus.delivered => 'Transporte concluído',
    TransportStatus.cancelled => 'Transporte cancelado',
  };

  @override
  Widget build(BuildContext context) {
    if (status.finished) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.mint,
          borderRadius: AppRadii.r15,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == TransportStatus.delivered
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(width: 9),
            Text(label, style: AppTextStyles.primaryStrong),
          ],
        ),
      );
    }
    return FilledButton.icon(
      onPressed: busy || !enabled ? null : onPressed,
      icon: busy
          ? const AppLoadingIndicator.button(dimension: 20)
          : const Icon(Icons.arrow_forward_rounded),
      label: Text(busy ? 'Confirmando...' : label),
    );
  }
}
