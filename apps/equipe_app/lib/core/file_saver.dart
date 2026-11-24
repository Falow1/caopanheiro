import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the person did in the "Save as" window.
enum SaveOutcome {
  /// Picked a folder and the file was written there.
  saved,

  /// Closed the window without saving.
  cancelled,
}

/// Download is offered on this device: only Android has the "Save as"
/// window (MainActivity.kt); iPhone and iPad stay out until the project has
/// a checked iOS build.
bool get imageSaveAvailable => defaultTargetPlatform == TargetPlatform.android;

/// Saves a PNG where the person chooses. The tests replace it; a failure
/// comes out as an exception.
abstract interface class FileSaver {
  Future<SaveOutcome> savePng(String name, Uint8List bytes);
}

/// The Android "Save as" window, through the `caopanheiro/files` channel of
/// MainActivity.kt.
class PlatformFileSaver implements FileSaver {
  const PlatformFileSaver();

  static const channel = MethodChannel('caopanheiro/files');

  @override
  Future<SaveOutcome> savePng(String name, Uint8List bytes) async {
    final answer = await channel.invokeMethod<String>('savePng', {
      'name': name,
      'bytes': bytes,
    });
    return switch (answer) {
      'saved' => SaveOutcome.saved,
      'cancelled' => SaveOutcome.cancelled,
      _ => throw StateError('Resposta inesperada ao salvar: $answer'),
    };
  }
}

/// Saves a text document (the CSV files of the data export, E2) where the
/// person chooses, through the same "Save as" window. The tests replace it.
abstract interface class DocumentSaver {
  Future<SaveOutcome> saveDocument(
    String name,
    Uint8List bytes,
    String mimeType,
  );
}

/// The same Android channel as [PlatformFileSaver], for a CSV file.
class PlatformDocumentSaver implements DocumentSaver {
  const PlatformDocumentSaver();

  @override
  Future<SaveOutcome> saveDocument(
    String name,
    Uint8List bytes,
    String mimeType,
  ) async {
    final answer = await PlatformFileSaver.channel.invokeMethod<String>(
      'saveFile',
      {'name': name, 'bytes': bytes, 'mime': mimeType},
    );
    return switch (answer) {
      'saved' => SaveOutcome.saved,
      'cancelled' => SaveOutcome.cancelled,
      _ => throw StateError('Resposta inesperada ao salvar: $answer'),
    };
  }
}
