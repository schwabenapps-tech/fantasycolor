import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/coloring_page.dart';

/// Exportiert Ausmal-Vorlagen zum Speichern (Fotos) oder Teilen/Drucken.
class PrintTemplateExport {
  PrintTemplateExport._();

  static Future<Uint8List> loadAssetBytes(ColoringPage page) async {
    final data = await rootBundle.load(page.assetPath);
    return data.buffer.asUint8List();
  }

  /// Speichert die leere Vorlage in der Geräte-Fotogalerie.
  static Future<void> saveToPhotos(ColoringPage page) async {
    final granted = await Gal.requestAccess();
    if (!granted) {
      throw const PrintTemplateExportException(
        'Kein Zugriff auf die Fotos. Bitte in den Einstellungen erlauben.',
      );
    }

    final bytes = await loadAssetBytes(page);
    await Gal.putImageBytes(
      bytes,
      name: 'fantasy_color_${page.id}',
    );
  }

  /// Öffnet das Teilen-Menü (Druck, AirDrop, Dateien, …).
  static Future<void> shareOrPrint(ColoringPage page) async {
    final bytes = await loadAssetBytes(page);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/fantasy_color_${page.id}.png');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: 'image/png',
            name: '${page.title}.png',
          ),
        ],
        subject: 'Ausmalvorlage: ${page.title}',
        text: 'Fantasy Color – Ausmalvorlage zum Ausdrucken',
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
