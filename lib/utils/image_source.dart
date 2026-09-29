import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bundle-Asset (`assets/…`) oder lokale Datei (Remote-Pack).
bool isAssetPath(String path) => path.startsWith('assets/');

ImageProvider imageProviderFor(String path) {
  if (isAssetPath(path)) {
    return AssetImage(path);
  }
  return FileImage(File(path));
}

Future<Uint8List> loadImageBytes(String path) async {
  if (isAssetPath(path)) {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }
  return File(path).readAsBytes();
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
