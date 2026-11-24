import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppStatusBadge;

import '../../core/app_theme.dart';

/// Item of the Mais screen: the icon on a mint tile and the name, inside a
/// card. The Mais of one company and the one of "Todas as empresas" share
/// it, so both lists look the same.
class MoreMenuTile extends StatelessWidget {
  const MoreMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.count = 0,
    this.lockedLabel,
    this.soonLabel,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  /// Items waiting for a decision, such as return requests of the link.
  final int count;

  /// Plan that includes this area, when the current plan does not (A1).
  final String? lockedLabel;

  /// Area announced but not available yet, such as payments in the app (E2).
  final String? soonLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color == null
                ? AppColors.mint
                : AppColors.dangerActionSurface,
            borderRadius: AppRadii.r13,
          ),
          child: Icon(icon, color: color ?? AppColors.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.ink,
          ),
        ),
        trailing: soonLabel != null
            ? AppStatusBadge(
                label: soonLabel!,
                background: AppColors.inactiveSurface,
                foreground: AppColors.inactiveInk,
              )
            : lockedLabel != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppStatusBadge(
                    label: lockedLabel!,
                    background: AppColors.inactiveSurface,
                    foreground: AppColors.inactiveInk,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.lock_outline_rounded, size: 20),
                ],
              )
            : count == 0
            ? const Icon(Icons.chevron_right_rounded)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppStatusBadge(
                    label: count == 1 ? '1 pedido' : '$count pedidos',
                    background: AppColors.pendingSurface,
                    foreground: AppColors.pendingInk,
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
      ),
    ),
  );
}
