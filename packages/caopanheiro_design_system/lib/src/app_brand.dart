import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Shared renderer with explicit variants preserving each original app mark.
class AppBrand extends StatelessWidget {
  const AppBrand({
    super.key,
    required this.product,
    this.compact = false,
    this.background = AppColors.primary,
    this.nameColor,
    this.productColor = AppColors.primary,
    this.productTracking = AppTypography.brandTracking,
    this.icon = Icons.pets_rounded,
    this.circular = false,
    this.mark,
  });

  const AppBrand.tutor({Key? key, bool compact = false})
    : this(
        key: key,
        product: '',
        compact: compact,
        nameColor: AppColors.primaryDark,
        circular: true,
        mark: const Center(child: AppPawMark()),
      );

  const AppBrand.team({Key? key, bool compact = false})
    : this(
        key: key,
        product: 'EQUIPE',
        compact: compact,
        nameColor: AppColors.navy,
        productTracking: AppTypography.teamBrandTracking,
      );

  const AppBrand.professional({Key? key, bool compact = false})
    : this(
        key: key,
        product: 'PROFISSIONAL',
        compact: compact,
        nameColor: AppColors.navy,
      );

  const AppBrand.driver({Key? key, bool compact = false})
    : this(key: key, product: 'ENTREGADOR', compact: compact);

  const AppBrand.platform({Key? key, bool compact = false})
    : this(
        key: key,
        product: 'PLATAFORMA',
        compact: compact,
        background: AppColors.navy,
        nameColor: AppColors.navy,
        productColor: AppColors.violet,
        productTracking: AppTypography.platformBrandTracking,
        icon: Icons.hub_rounded,
      );

  final String product;
  final bool compact;
  final Color background;
  final Color? nameColor;
  final Color productColor;
  final double productTracking;
  final IconData icon;
  final bool circular;
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    final originalTitle = Theme.of(context).textTheme.titleLarge;
    final name = Text(
      'cãopanheiro',
      style: nameColor == null
          ? originalTitle
          : originalTitle?.copyWith(color: nameColor),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppDimensions.brandSize,
          height: AppDimensions.brandSize,
          decoration: BoxDecoration(
            color: background,
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circular ? null : AppRadii.brand,
          ),
          child: mark ?? Icon(icon, color: Colors.white),
        ),
        if (!compact) ...[
          const SizedBox(width: AppSpacing.brandGap),
          if (product.isEmpty)
            name
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                name,
                Text(
                  product.toUpperCase(),
                  style: TextStyle(
                    color: productColor,
                    fontSize: AppTypography.brandProductSize,
                    fontWeight: AppTypography.brandWeight,
                    letterSpacing: productTracking,
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

/// The paw of the Tutor mark, drawn from the installed PWA icon
/// (apps/tutor_app/web/icon.svg): four oval toes in an arc over the pad.
/// Decorative; the name next to it carries the meaning.
class AppPawMark extends StatelessWidget {
  const AppPawMark({super.key, this.size = 26, this.color = Colors.white});

  /// Side of the square the paw is fitted and centred in.
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _PawPainter(color)),
  );

  /// The same paw, fitted and centred in [rect] of any canvas, for drawings
  /// made without widgets, such as the printable invite poster.
  static void paintIn(Canvas canvas, Rect rect, Color color) {
    canvas
      ..save()
      ..translate(rect.left, rect.top);
    _PawPainter(color).paint(canvas, rect.size);
    canvas.restore();
  }
}

class _PawPainter extends CustomPainter {
  const _PawPainter(this.color);
  final Color color;

  /// Area of the paw in the 512 grid of icon.svg.
  static const _bounds = Rect.fromLTRB(90, 89, 422, 406);

  /// Toes of icon.svg: centre, radii and tilt in degrees.
  static const _toes = [
    (128.0, 216.0, 34.0, 45.0, -30.0),
    (204.0, 140.0, 38.0, 51.0, -11.0),
    (308.0, 140.0, 38.0, 51.0, 11.0),
    (384.0, 216.0, 34.0, 45.0, 30.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / _bounds.width,
      size.height / _bounds.height,
    );
    final paint = Paint()..color = color;
    canvas
      ..save()
      ..translate(
        (size.width - _bounds.width * scale) / 2,
        (size.height - _bounds.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-_bounds.left, -_bounds.top);
    for (final (x, y, rx, ry, tilt) in _toes) {
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(tilt * math.pi / 180)
        ..drawOval(
          Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
          paint,
        )
        ..restore();
    }
    final pad = Path()
      ..moveTo(256, 226)
      ..cubicTo(184, 226, 134, 296, 134, 350)
      ..cubicTo(134, 394, 170, 420, 212, 398)
      ..cubicTo(240, 383, 272, 383, 300, 398)
      ..cubicTo(342, 420, 378, 394, 378, 350)
      ..cubicTo(378, 296, 328, 226, 256, 226)
      ..close();
    canvas
      ..drawPath(pad, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_PawPainter oldDelegate) => oldDelegate.color != color;
}
