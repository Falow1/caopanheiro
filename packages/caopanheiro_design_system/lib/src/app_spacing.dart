import 'package:flutter/material.dart';

/// Existing spacing values. Do not introduce a new scale during centralization.
abstract final class AppSpacing {
  static const brandGap = 12.0;
  static const sectionGap = 12.0;
  static const page = EdgeInsets.fromLTRB(20, 12, 20, 30);
  static const tutorPage = EdgeInsets.fromLTRB(20, 12, 20, 28);
  static const form = EdgeInsets.fromLTRB(20, 8, 20, 30);
  static const input = EdgeInsets.symmetric(horizontal: 17, vertical: 16);
  static const badge = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
  static const teamHeader = EdgeInsets.fromLTRB(20, 24, 20, 14);
  static const teamPage = EdgeInsets.fromLTRB(20, 24, 20, 32);
  static const teamList = EdgeInsets.fromLTRB(20, 4, 20, 32);
}
