import 'package:flutter/widgets.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors;
import 'package:qr/qr.dart';

/// QR Code of the petshop's fixed invite link. The `qr` package only
/// computes the modules; the drawing is the project's own.
class InviteQr {
  InviteQr._(this.data, this._image, this.level);

  /// Level Q, which survives printing and wear, while the address fits up to
  /// version 15; past that, level M keeps the modules large enough to read.
  factory InviteQr(String data) {
    final payload = QrPayload.fromString(data);
    var level = QrErrorCorrectLevel.quartile;
    var code = QrCode(payload: payload, errorCorrectLevel: level);
    if (code.typeNumber > 15) {
      level = QrErrorCorrectLevel.medium;
      code = QrCode(payload: payload, errorCorrectLevel: level);
    }
    return InviteQr._(data, QrImage(code), level);
  }

  /// The encoded address.
  final String data;
  final QrImage _image;
  final QrErrorCorrectLevel level;

  /// White margin required around the code, in modules.
  static const quietZone = 4;

  int get version => _image.typeNumber;
  int get modules => _image.moduleCount;

  /// Modules on each side, the white margin included.
  int get span => modules + 2 * quietZone;

  bool dark(int row, int column) => _image.isDark(row, column);

  /// Square of the code with its white margin inside [area], centred. Each
  /// module takes a whole number of pixels when there is room, and the corner
  /// falls on a whole pixel, so the printed file has no blurred edges: the
  /// phone's GPU blends an edge that crosses a pixel even without
  /// antialiasing. What is left over becomes extra margin. On screen,
  /// [pixelRatio] is the device's, so the count is of its physical pixels.
  Rect codeArea(Rect area, {double pixelRatio = 1}) {
    final side = area.shortestSide;
    final module = side * pixelRatio / span;
    if (module < 2) {
      return Rect.fromCenter(center: area.center, width: side, height: side);
    }
    final size = module.floorToDouble() * span;
    double snap(double value) =>
        (value * pixelRatio - size / 2).roundToDouble() / pixelRatio;
    final logical = size / pixelRatio;
    return Rect.fromLTWH(
      snap(area.center.dx),
      snap(area.center.dy),
      logical,
      logical,
    );
  }

  /// Paints the code with its white margin inside [area] (see [codeArea]).
  void paint(
    Canvas canvas,
    Rect area, {
    Color ink = AppColors.qrInk,
    Color paper = AppColors.paper,
    double pixelRatio = 1,
  }) {
    final side = area.shortestSide;
    final code = codeArea(area, pixelRatio: pixelRatio);
    final module = code.width / span;
    final origin = code.topLeft;
    canvas.drawRect(
      Rect.fromCenter(center: area.center, width: side, height: side),
      Paint()..color = paper,
    );
    final path = Path();
    for (var row = 0; row < modules; row++) {
      var column = 0;
      while (column < modules) {
        if (!dark(row, column)) {
          column++;
          continue;
        }
        final start = column;
        while (column < modules && dark(row, column)) {
          column++;
        }
        path.addRect(
          Rect.fromLTWH(
            origin.dx + (start + quietZone) * module,
            origin.dy + (row + quietZone) * module,
            (column - start) * module,
            module,
          ),
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..isAntiAlias = false,
    );
  }
}

/// The invite QR Code on screen, black on white like the file, large enough
/// to be read straight from the screen.
class InviteQrView extends StatelessWidget {
  const InviteQrView({super.key, required this.qr, this.size = 200});
  final InviteQr qr;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'QR Code do link de convite',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _InviteQrPainter(qr, MediaQuery.devicePixelRatioOf(context)),
      ),
    ),
  );
}

class _InviteQrPainter extends CustomPainter {
  const _InviteQrPainter(this.qr, this.pixelRatio);
  final InviteQr qr;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) =>
      qr.paint(canvas, Offset.zero & size, pixelRatio: pixelRatio);

  @override
  bool shouldRepaint(_InviteQrPainter oldDelegate) =>
      oldDelegate.qr != qr || oldDelegate.pixelRatio != pixelRatio;
}
