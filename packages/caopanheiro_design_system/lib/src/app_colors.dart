import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF173A3D);
  static const ink = Color(0xFF18302F);
  static const primary = Color(0xFF176B65);
  static const primaryDark = Color(0xFF0B4F43);
  static const mint = Color(0xFFDDEEE8);
  static const orange = Color(0xFFF08A5D);
  static const coral = orange;
  static const cream = Color(0xFFF8F6F0);
  static const canvas = Color(0xFFF4F6F3);
  static const paper = Color(0xFFFFFFFF);
  static const muted = Color(0xFF687A77);
  static const line = Color(0xFFE1E8E4);
  static const offlineBackground = Color(0xFFB3261E);
  static const danger = Color(0xFFC65353);
  static const warning = Color(0xFF9B5B16);
  static const violet = Color(0xFF60468A);

  // Existing contextual variants; applications retain their status mappings.
  static const pendingSurface = Color(0xFFFFF0CE);
  static const pendingInk = Color(0xFF8A5A00);
  static const receivedSurface = Color(0xFFE7E2F4);
  static const progressSurface = Color(0xFFFFE4D6);
  static const progressInk = Color(0xFF9B462E);
  static const completedSurface = Color(0xFFDCEADF);
  static const completedInk = Color(0xFF386341);
  static const cancelledSurface = Color(0xFFF3DDDD);
  static const cancelledInk = Color(0xFF9A3B3B);
  static const inactiveSurface = Color(0xFFE7E9E8);
  static const inactiveInk = Color(0xFF59625F);
  static const tutorPendingSurface = Color(0xFFFFF1CE);
  static const tutorConfirmedSurface = Color(0xFFDDEFE9);
  static const tutorReceivedSurface = Color(0xFFE8E4F6);
  static const tutorReceivedInk = Color(0xFF5B4587);
  static const tutorProgressSurface = Color(0xFFFFE5D7);
  static const tutorProgressInk = Color(0xFF9D462F);
  static const tutorCompletedSurface = Color(0xFFDDEDE2);
  static const tutorCompletedInk = Color(0xFF35633F);
  static const tutorCancelledSurface = Color(0xFFF5DEDE);
  static const tutorCancelledInk = Color(0xFF9F3D3D);
  static const tutorHeroAccent = Color(0xFFFFD4A8);
  static const tutorHeroSecondary = Color(0xFFFFE8CF);
  static const dangerActionSurface = Color(0xFFF4DEDE);
  static const tenantPendingSurface = Color(0xFFFFEBCF);
  static const tenantPendingInk = Color(0xFF956316);
  static const noticeSurface = Color(0xFFFFECDD);
  static const onboardingPendingSurface = Color(0xFFF0E6E1);

  /// Modules of the invite QR Code, pure black on [paper] for the camera
  /// (decision Q4 of the fixed link plan); not used by other components.
  static const qrInk = Color(0xFF000000);
}
