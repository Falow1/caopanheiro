import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Only the original local overrides. All other properties inherit AppTheme.
/// Keep button types and callbacks in the app: no new behavior is introduced.
abstract final class AppButtonStyles {
  static ButtonStyle get dangerFilled =>
      FilledButton.styleFrom(backgroundColor: AppColors.danger);

  static ButtonStyle get dangerText =>
      TextButton.styleFrom(foregroundColor: AppColors.danger);

  static ButtonStyle get dangerOutlined =>
      OutlinedButton.styleFrom(foregroundColor: AppColors.danger);

  static ButtonStyle get dangerOutlinedTutor => OutlinedButton.styleFrom(
    foregroundColor: AppColors.danger,
    side: const BorderSide(color: Color(0xFFE9CACA)),
  );

  static ButtonStyle get dangerOutlinedPlatform => OutlinedButton.styleFrom(
    foregroundColor: AppColors.danger,
    side: const BorderSide(color: Color(0xFFE7CACA)),
  );

  static ButtonStyle get textOnDark => TextButton.styleFrom(
    foregroundColor: Colors.white,
    padding: EdgeInsets.zero,
  );
}
