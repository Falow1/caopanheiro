import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'invite_poster.dart';
import 'invite_qr.dart';

/// Side of the QR Code file, black on white with its white margin.
const qrFileSide = 1024;

/// Draws [paint] on a canvas of [size] pixels and encodes it as PNG, without
/// any widget on screen.
Future<Uint8List> renderPng(
  Size size,
  void Function(Canvas canvas, Size size) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder, Offset.zero & size), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<Uint8List> qrPng(InviteQr qr) => renderPng(
  Size(qrFileSide.toDouble(), qrFileSide.toDouble()),
  (canvas, size) => qr.paint(canvas, Offset.zero & size),
);

Future<Uint8List> posterPng(InvitePoster poster) =>
    renderPng(InvitePoster.fileSize, poster.paint);

/// File name without accents, spaces or symbols, such as
/// `caopanheiro-qr-pet-feliz.png`.
String inviteFileName(String kind, String petshop) {
  const plain = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ç': 'c', 'ñ': 'n',
  };
  final slug = petshop
      .toLowerCase()
      .split('')
      .map((char) => plain[char] ?? char)
      .join()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final name = slug.isEmpty
      ? 'petshop'
      : slug.substring(0, slug.length > 40 ? 40 : slug.length);
  return 'caopanheiro-$kind-${name.replaceAll(RegExp(r'-+$'), '')}.png';
}
