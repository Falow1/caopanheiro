import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// What the person did with an image offered to the share window.
enum ShareOutcome {
  /// Picked an app (WhatsApp, printer, files).
  shared,

  /// Closed the window without picking one.
  dismissed,

  /// The system does not tell what was picked.
  unknown,
}

/// The share window is offered on this device. iPhone and iPad stay out
/// until the project has a checked iOS build: there the area shows the
/// QR Code on screen without the buttons.
bool get imageShareAvailable => defaultTargetPlatform != TargetPlatform.iOS;

/// Offers a PNG to the system share window. The tests replace it; a failure
/// comes out as an exception.
abstract interface class ImageSharer {
  Future<ShareOutcome> sharePng(
    String name,
    Uint8List bytes, {
    required String title,
  });
}

/// The share window of the system, through `share_plus`: the image goes to
/// a temporary file under [name] and the window offers it to the apps.
class PlatformImageSharer implements ImageSharer {
  const PlatformImageSharer();

  @override
  Future<ShareOutcome> sharePng(
    String name,
    Uint8List bytes, {
    required String title,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        title: title,
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
        fileNameOverrides: [name],
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.shared,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unknown,
    };
  }
}

/// Offers several files at once to the share window (the CSV files of the
/// data export, E2). The tests replace it.
abstract interface class FilesSharer {
  Future<ShareOutcome> shareFiles(
    List<(String name, Uint8List bytes, String mimeType)> files, {
    required String title,
  });
}

class PlatformFilesSharer implements FilesSharer {
  const PlatformFilesSharer();

  @override
  Future<ShareOutcome> shareFiles(
    List<(String name, Uint8List bytes, String mimeType)> files, {
    required String title,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        title: title,
        files: [
          for (final file in files)
            XFile.fromData(file.$2, mimeType: file.$3, name: file.$1),
        ],
        fileNameOverrides: [for (final file in files) file.$1],
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.shared,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unknown,
    };
  }
}
