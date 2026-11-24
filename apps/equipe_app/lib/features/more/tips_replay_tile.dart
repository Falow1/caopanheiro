import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTourTarget;
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/screen_tips.dart';
import '../../state/app_scope.dart';

/// "Rever dicas" of the Ajuda section: erases the account marks, so every
/// screen shows its tips again, starting with the one open now.
class TipsReplayTile extends StatelessWidget {
  const TipsReplayTile({super.key});

  @override
  Widget build(BuildContext context) => AppTourTarget(
    id: TipTargets.help,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: ListTile(
          onTap: () {
            AppScope.of(context).resetTips();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Pronto. As dicas aparecem de novo em cada tela.',
                ),
              ),
            );
          },
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: AppRadii.r13,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.primary,
            ),
          ),
          title: const Text(
            'Rever dicas',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          subtitle: const Text('Mostra de novo as dicas de cada tela.'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    ),
  );
}
