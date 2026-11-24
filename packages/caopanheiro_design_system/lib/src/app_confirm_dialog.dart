import 'package:flutter/material.dart';

import 'app_button_styles.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_text_styles.dart';

/// Neutral for ordinary steps; danger for actions that delete, cancel,
/// unlink or remove access.
enum AppConfirmTone { neutral, danger }

/// Shared confirmation for actions with consequence. Returns true only when
/// the confirm button is pressed: Cancel, tapping outside and the system back
/// return false. Dialogs with fields or choices stay local and use the theme.
Future<bool> showAppConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  AppConfirmTone tone = AppConfirmTone.neutral,
  IconData? icon,
  List<(String label, String value)> details = const [],
  String? note,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AppConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      tone: tone,
      icon: icon,
      details: details,
      note: note,
    ),
  );
  return confirmed == true;
}

/// Content of [showAppConfirmation]; still an [AlertDialog] underneath.
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancelar',
    this.tone = AppConfirmTone.neutral,
    this.icon,
    this.details = const [],
    this.note,
  });
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final AppConfirmTone tone;
  final IconData? icon;
  final List<(String label, String value)> details;
  final String? note;

  bool get _danger => tone == AppConfirmTone.danger;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = _danger ? AppColors.danger : AppColors.primary;
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _danger ? AppColors.dangerActionSurface : AppColors.mint,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon ??
              (_danger
                  ? Icons.warning_amber_rounded
                  : Icons.help_outline_rounded),
          color: accent,
          size: 28,
        ),
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: AppRadii.r15,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, (label, value)) in details.indexed) ...[
                    if (index > 0) const SizedBox(height: 8),
                    Text(label, style: AppTextStyles.captionMuted),
                    Text(value, style: AppTextStyles.value),
                  ],
                ],
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note!,
                    style: text.bodyMedium?.copyWith(
                      color: _danger ? AppColors.danger : AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                style: _danger ? AppButtonStyles.dangerFilled : null,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
