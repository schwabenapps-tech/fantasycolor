import 'dart:typed_data';

import 'package:gal/gal.dart';

/// Speichert ausgemalte PNGs in die Geräte-Fotogalerie (iOS + Android).
class GalleryExport {
  GalleryExport._();

  static Future<void> savePngBytes(
    Uint8List bytes, {
    required String name,
  }) async {
    final granted = await Gal.requestAccess();
    if (!granted) {
      throw const GalleryExportException(
        'Kein Zugriff auf die Fotos. Bitte in den Einstellungen erlauben.',
      );
    }
    await Gal.putImageBytes(bytes, name: name);
  }
}

class GalleryExportException implements Exception {
  const GalleryExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
