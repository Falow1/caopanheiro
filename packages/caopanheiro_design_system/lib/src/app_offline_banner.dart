import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radii.dart';

/// Only the offline notice has a red background; policy remains in each app.
/// A rounded card with a cloud icon, inset from the screen edges by [margin]
/// so each app can line it up with its own page content. With enlarged text
/// the decorative icon gives its width to the message, which stays whole.
class AppOfflineBanner extends StatelessWidget {
  const AppOfflineBanner({
    super.key,
    this.message = defaultMessage,
    this.margin = const EdgeInsets.fromLTRB(8, 8, 8, 0),
  });
  static const defaultMessage = 'Consulta offline · somente leitura';
  final String message;
  final EdgeInsetsGeometry margin;
  @override
  Widget build(BuildContext context) {
    final icon = MediaQuery.textScalerOf(context).scale(1) < 1.5;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: margin,
        child: Material(
          color: AppColors.offlineBackground,
          borderRadius: AppRadii.r12,
          child: Padding(
            padding: icon
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                : const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                if (icon) ...[
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
