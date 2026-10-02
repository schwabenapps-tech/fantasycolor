import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/coloring_page.dart';
import '../utils/image_source.dart';

/// Exportiert Ausmal-Vorlagen zum Speichern (Fotos) oder Teilen/Drucken.
class PrintTemplateExport {
  PrintTemplateExport._();

  /// Dateiname ohne Erweiterung, z. B. `Fairy Fantasy Color 3`.
  static String exportBaseName(ColoringPage page) {
    final title = page.title.trim();
    if (title.isNotEmpty) return title;
    return 'Fairy Fantasy Color';
  }

  static Future<Uint8List> loadAssetBytes(ColoringPage page) async {
    return loadImageBytes(page.assetPath);
  }

  /// Speichert die leere Vorlage in der Geräte-Fotogalerie.
  static Future<void> saveToPhotos(ColoringPage page) async {
    final granted = await Gal.requestAccess();
    if (!granted) {
      throw const PrintTemplateExportException(
        'Kein Zugriff auf die Fotos. Bitte in den Settings erlauben.',
      );
    }

    final bytes = await loadAssetBytes(page);
    await Gal.putImageBytes(
      bytes,
      name: exportBaseName(page),
    );
  }

  /// Öffnet das Teilen-Menü (Druck, AirDrop, Dateien, …).
  ///
  /// [sharePositionOrigin] ist auf iPad nötig (Popover-Anker).
  static Future<void> shareOrPrint(
    ColoringPage page, {
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await loadAssetBytes(page);
    final baseName = exportBaseName(page);
    final dir = await getTemporaryDirectory();
    final safeFileStem = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/$safeFileStem.png');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: 'image/png',
            name: '$baseName.png',
          ),
        ],
        subject: baseName,
        text: 'Fairy Fantasy Color – printable coloring page',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

class PrintTemplateExportException implements Exception {
  const PrintTemplateExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
