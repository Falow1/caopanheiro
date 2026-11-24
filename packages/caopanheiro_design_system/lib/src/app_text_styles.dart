import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Recurrent original overrides. Unspecified properties still inherit locally.
abstract final class AppTextStyles {
  static const caption = TextStyle(fontSize: 12);
  static const captionMuted = TextStyle(fontSize: 12, color: AppColors.muted);
  static const metadata = TextStyle(fontSize: 11, color: AppColors.muted);
  static const strong = TextStyle(fontWeight: FontWeight.w700);
  static const primaryStrong = TextStyle(
    color: AppColors.primary,
    fontWeight: FontWeight.w800,
  );
  static const value = TextStyle(
    color: AppColors.ink,
    fontWeight: FontWeight.w700,
  );
  static const emphasis = TextStyle(
    color: AppColors.ink,
    fontWeight: FontWeight.w800,
  );
  static const danger = TextStyle(
    color: AppColors.danger,
    fontWeight: FontWeight.w700,
  );
  static const onDarkSecondary = TextStyle(color: Colors.white70);
}
