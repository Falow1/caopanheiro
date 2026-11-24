import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors, AppPawMark, AppTypography;

import 'invite_qr.dart';

/// Printable A4 invite poster: brand, petshop name, the call, the QR Code
/// and three steps. Drawn on a canvas of any size with A4 proportions, so
/// the same drawing serves the preview and the 1654 × 2339 file.
class InvitePoster {
  const InvitePoster({required this.petshop, required this.qr});

  final String petshop;
  final InviteQr qr;

  /// A4 portrait at 200 dots per inch.
  static const fileSize = Size(1654, 2339);
  static const aspectRatio = 1654 / 2339;

  static const headline = 'Agende os cuidados do seu pet pelo celular';
  static const steps = [
    'Aponte a câmera do celular para o código',
    'Crie sua conta ou entre',
    'Pronto: agende quando quiser',
  ];

  void paint(Canvas canvas, Size size) {
    // Everything is laid out on the file's grid and scaled to [size].
    final scale = size.width / fileSize.width;
    canvas
      ..save()
      ..scale(scale);
    _draw(canvas);
    canvas.restore();
  }

  static const _w = 1654.0, _h = 2339.0;

  /// White sheet over the mint background.
  static const _sheet = Rect.fromLTWH(110, 330, _w - 220, _h - 450);
  static const _qrMin = 600.0, _qrMax = 860.0;

  /// Where the parts fall on the file's grid. The steps keep their place at
  /// the foot of the sheet; the QR Code takes the room a long name leaves,
  /// never below a size that reads from the counter.
  PosterLayout layout() {
    final name = _name();
    final headline = _painter(
      InvitePoster.headline,
      size: 60,
      color: AppColors.muted,
      weight: FontWeight.w700,
      maxWidth: 1000,
      maxLines: 3,
    );
    final nameTop = _sheet.top + 90;
    final headlineTop = nameTop + name.height + 30;
    final qrTop = headlineTop + headline.height + 60;
    final stepsBottom = _sheet.bottom - 90;
    final stepsTop = stepsBottom - _stepsHeight();
    final room = stepsTop - 70 - qrTop;
    final side = room.clamp(_qrMin, _qrMax);
    return PosterLayout._(
      name: name,
      nameTop: nameTop,
      headline: headline,
      headlineTop: headlineTop,
      // Centred in the room left between the call and the steps.
      qr: Rect.fromLTWH(
        (_w - side) / 2,
        qrTop + math.max(0, room - side) / 2,
        side,
        side,
      ),
      stepsTop: stepsTop,
      stepsBottom: stepsBottom,
      accentTop: _sheet.bottom - 46,
    );
  }

  /// Mint background, the brand above a white sheet with the name, the call,
  /// the QR Code and the three steps side by side, and an orange accent at
  /// the foot: option B, chosen by the user among the three arts shown.
  void _draw(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _w, _h),
      Paint()..color = AppColors.mint,
    );
    _brand(canvas, const Offset(_w / 2, 190));
    canvas.drawRRect(
      RRect.fromRectAndRadius(_sheet, const Radius.circular(64)),
      Paint()..color = AppColors.paper,
    );
    final parts = layout();
    for (final (painter, top) in [
      (parts._name, parts.nameTop),
      (parts._headline, parts.headlineTop),
    ]) {
      painter.paint(canvas, Offset((_w - painter.width) / 2, top));
    }
    qr.paint(canvas, parts.qr, paper: AppColors.paper);
    _stepsRow(canvas, parts.stepsTop);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_w / 2 - 120, parts.accentTop, 240, 14),
        const Radius.circular(7),
      ),
      Paint()..color = AppColors.orange,
    );
  }

  /// Paw in a circle and the name, centred on [center].
  void _brand(Canvas canvas, Offset center) {
    final label = _painter(
      'cãopanheiro',
      size: 84,
      color: AppColors.primaryDark,
      weight: FontWeight.w800,
      maxWidth: 1000,
    );
    const radius = 70.0, gap = 34.0;
    final width = radius * 2 + gap + label.width;
    final left = center.dx - width / 2;
    final circleCenter = Offset(left + radius, center.dy);
    canvas.drawCircle(circleCenter, radius, Paint()..color = AppColors.primary);
    AppPawMark.paintIn(
      canvas,
      Rect.fromCenter(center: circleCenter, width: 92, height: 92),
      AppColors.paper,
    );
    label.paint(
      canvas,
      Offset(left + radius * 2 + gap, center.dy - label.height / 2),
    );
  }

  /// Petshop name in up to two lines, smaller for long names, down to 60.
  TextPainter _name() {
    for (var size = 120.0; ; size -= 6) {
      final painter = _painter(
        petshop,
        size: size,
        color: AppColors.ink,
        weight: FontWeight.w800,
        maxWidth: _sheet.width - 160,
        maxLines: 2,
      );
      if (!painter.didExceedMaxLines || size <= 60) return painter;
    }
  }

  static const _stepRadius = 44.0, _stepTextTop = 110.0;
  static const _stepColumn = (_w - 220 - 120) / 3;

  static TextPainter _step(String step) => _painter(
    step,
    size: 44,
    color: AppColors.ink,
    weight: FontWeight.w600,
    maxWidth: _stepColumn - 40,
    maxLines: 3,
  );

  /// Height of the steps: the numbers and the tallest text under them.
  static double _stepsHeight() =>
      _stepTextTop + steps.map((step) => _step(step).height).reduce(math.max);

  void _stepsRow(Canvas canvas, double top) {
    for (final (index, step) in steps.indexed) {
      final x = _sheet.left + 60 + _stepColumn * index;
      _number(
        canvas,
        Offset(x + _stepColumn / 2, top + _stepRadius),
        index + 1,
      );
      final text = _step(step);
      text.paint(
        canvas,
        Offset(x + (_stepColumn - text.width) / 2, top + _stepTextTop),
      );
    }
  }

  void _number(Canvas canvas, Offset center, int value) {
    canvas.drawCircle(center, _stepRadius, Paint()..color = AppColors.primary);
    final digit = _painter(
      '$value',
      size: 52,
      color: AppColors.paper,
      weight: FontWeight.w800,
      maxWidth: 88,
    );
    digit.paint(canvas, center - Offset(digit.width / 2, digit.height / 2));
  }

  static TextPainter _painter(
    String text, {
    required double size,
    required Color color,
    required FontWeight weight,
    required double maxWidth,
    int? maxLines,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: AppTypography.family,
        fontSize: size,
        height: 1.18,
        color: color,
        fontWeight: weight,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  )..layout(maxWidth: maxWidth);
}

/// Parts of the poster on the 1654 × 2339 grid.
class PosterLayout {
  const PosterLayout._({
    required this._name,
    required this.nameTop,
    required this._headline,
    required this.headlineTop,
    required this.qr,
    required this.stepsTop,
    required this.stepsBottom,
    required this.accentTop,
  });

  final TextPainter _name, _headline;
  final double nameTop, headlineTop, stepsTop, stepsBottom, accentTop;

  /// Square of the QR Code with its white margin.
  final Rect qr;

  double get nameSize => _name.text!.style!.fontSize!;
  int get nameLines => _name.computeLineMetrics().length;
  bool get nameCut => _name.didExceedMaxLines;
}
