import 'package:flutter/material.dart';

/// Google sign-in button with the provider's own presentation: white surface,
/// neutral outline and the four-colour "G". These brand colours belong to the
/// provider and are intentionally not part of the application palette.
class AppGoogleButton extends StatelessWidget {
  const AppGoogleButton({
    super.key,
    required this.onPressed,
    this.label = 'Continuar com Google',
  });

  /// Null disables the button, as in the Material buttons.
  final VoidCallback? onPressed;
  final String label;

  static const _surface = Color(0xFFFFFFFF);
  static const _outline = Color(0xFF747775);
  static const _ink = Color(0xFF1F1F1F);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: _surface,
        disabledBackgroundColor: _surface,
        foregroundColor: _ink,
        disabledForegroundColor: _ink.withValues(alpha: 0.38),
        side: BorderSide(
          color: enabled ? _outline : _outline.withValues(alpha: 0.38),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: enabled ? 1 : 0.38,
            child: const AppGoogleLogo(size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The provider's "G" mark, drawn without an image asset.
class AppGoogleLogo extends StatelessWidget {
  const AppGoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GoogleLogoPainter()),
    ),
  );
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _red = Color(0xFFEA4335);
  static const _blue = Color(0xFF4285F4);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    // Paths follow the official mark on a 48 x 48 grid.
    canvas.scale(size.width / 48, size.height / 48);
    final paint = Paint()..style = PaintingStyle.fill;

    final red = Path()
      ..moveTo(24, 9.5)
      ..relativeCubicTo(3.54, 0, 6.71, 1.22, 9.21, 3.6)
      ..relativeLineTo(6.85, -6.85)
      ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
      ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
      ..relativeLineTo(7.98, 6.19)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
      ..close();
    canvas.drawPath(red, paint..color = _red);

    final blue = Path()
      ..moveTo(46.98, 24.55)
      ..relativeCubicTo(0, -1.57, -0.15, -3.09, -0.38, -4.55)
      ..lineTo(24, 20)
      ..relativeLineTo(0, 9.02)
      ..relativeLineTo(12.94, 0)
      ..relativeCubicTo(-0.58, 2.96, -2.26, 5.48, -4.78, 7.18)
      ..relativeLineTo(7.73, 6)
      ..relativeCubicTo(4.51, -4.18, 7.09, -10.36, 7.09, -17.65)
      ..close();
    canvas.drawPath(blue, paint..color = _blue);

    final yellow = Path()
      ..moveTo(10.53, 28.59)
      ..relativeCubicTo(-0.48, -1.45, -0.76, -2.99, -0.76, -4.59)
      ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
      ..relativeLineTo(-7.98, -6.19)
      ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
      ..relativeCubicTo(0, 3.88, 0.92, 7.54, 2.56, 10.78)
      ..relativeLineTo(7.97, -6.19)
      ..close();
    canvas.drawPath(yellow, paint..color = _yellow);

    final green = Path()
      ..moveTo(24, 48)
      ..relativeCubicTo(6.48, 0, 11.93, -2.13, 15.89, -5.81)
      ..relativeLineTo(-7.73, -6)
      ..relativeCubicTo(-2.15, 1.45, -4.92, 2.3, -8.16, 2.3)
      ..relativeCubicTo(-6.26, 0, -11.57, -4.22, -13.47, -9.91)
      ..relativeLineTo(-7.98, 6.19)
      ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
      ..close();
    canvas.drawPath(green, paint..color = _green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
