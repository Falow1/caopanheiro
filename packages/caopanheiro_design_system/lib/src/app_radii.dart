import 'package:flutter/material.dart';

/// Original radii, without introducing organic shapes or a new visual style.
abstract final class AppRadii {
  static const brand = BorderRadius.all(Radius.circular(14));
  static const input = BorderRadius.all(Radius.circular(15));
  static const button = BorderRadius.all(Radius.circular(15));
  static const card = BorderRadius.all(Radius.circular(20));
  static const snackBar = BorderRadius.all(Radius.circular(12));
  static const badge = 99.0;
  static const tutorBadge = 999.0;

  // Existing screen radius scale; values deliberately preserved.
  static const r9 = BorderRadius.all(Radius.circular(9));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r13 = BorderRadius.all(Radius.circular(13));
  static const r14 = BorderRadius.all(Radius.circular(14));
  static const r15 = BorderRadius.all(Radius.circular(15));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r17 = BorderRadius.all(Radius.circular(17));
  static const r18 = BorderRadius.all(Radius.circular(18));
  static const r19 = BorderRadius.all(Radius.circular(19));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r22 = BorderRadius.all(Radius.circular(22));
  static const r24 = BorderRadius.all(Radius.circular(24));
  static const r99 = BorderRadius.all(Radius.circular(99));
}
