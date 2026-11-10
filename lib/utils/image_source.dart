import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bundle-Asset (`assets/…`) oder lokale Datei (Remote-Pack).
bool isAssetPath(String path) => path.startsWith('assets/');

/// Ob der Pfad fürs Decodieren bereit ist (Asset immer, Datei nur wenn vorhanden).
bool isLocalImageAvailable(String path) {
  if (path.isEmpty) return false;
  if (isAssetPath(path)) return true;
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

/// 1×1 transparentes PNG — Fallback statt FileImage auf fehlende Datei.
final Uint8List _kTransparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final MemoryImage transparentImageProvider = MemoryImage(_kTransparentPng);

ImageProvider imageProviderFor(String path) {
  if (isAssetPath(path)) {
    return AssetImage(path);
  }
  final file = File(path);
  try {
    if (!file.existsSync()) {
      return transparentImageProvider;
    }
  } catch (_) {
    return transparentImageProvider;
  }
  return FileImage(file);
}

Future<Uint8List> loadImageBytes(String path) async {
  if (isAssetPath(path)) {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }
  final file = File(path);
  if (!await file.exists()) {
    throw StateError('Lokale Bilddatei fehlt: $path');
  }
  return file.readAsBytes();
}

/// Precache für Assets und heruntergeladene Pack-Dateien.
Future<void> precacheImagePaths(
  BuildContext context,
  Iterable<String> paths, {
  int? cacheWidth,
}) async {
  for (final path in paths) {
    if (!context.mounted) return;
    if (path.isEmpty) continue;
    if (!isLocalImageAvailable(path)) continue;
    try {
      final base = imageProviderFor(path);
      final ImageProvider provider = cacheWidth == null
          ? base
          : ResizeImage(base, width: cacheWidth);
      await precacheImage(provider, context);
    } catch (_) {
      // Einzelne kaputte Dateien sollen den Rest nicht blockieren.
    }
  }
}

/// Fehlende/kaputte Remote- oder Progress-Bilder (Galerie, Stickers).
Widget missingImagePlaceholder({
  Color color = const Color(0xFF8FA0C8),
  double size = 28,
}) {
  return Center(
    child: Icon(Icons.broken_image_outlined, color: color, size: size),
  );
}

/// Typische Flutter-Image-/Datei-Fehler, die keine echten App-Crashes sind.
bool isBenignImageLoadError(Object error) {
  if (error is PathNotFoundException) return true;
  if (error is FileSystemException) {
    final code = error.osError?.errorCode;
    // ENOENT (POSIX) / ERROR_FILE_NOT_FOUND (Windows).
    if (code == 2) return true;
  }
  final text = error.toString();
  if (text.contains('PathNotFoundException')) return true;
  if (text.contains('FileImage')) return true;
  if (text.contains('Failed to load')) return true;
  if (text.contains('Cannot retrieve length of file')) return true;
  if (text.contains('Lokale Bilddatei fehlt')) return true;
  return false;
}
