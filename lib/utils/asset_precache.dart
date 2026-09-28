import 'package:flutter/material.dart';

/// Lokale Asset-Bilder sind im Bundle, müssen aber trotzdem dekodiert werden.
/// Precache hält sie im ImageCache, damit schnelles Scrollen/Sliden nicht leer wirkt.
Future<void> precacheAssetImages(
  BuildContext context,
  Iterable<String> assetPaths, {
  int? cacheWidth,
}) async {
  for (final path in assetPaths) {
    if (!context.mounted) return;
    if (path.isEmpty) continue;
    try {
      final ImageProvider provider = cacheWidth == null
          ? AssetImage(path)
          : ResizeImage(AssetImage(path), width: cacheWidth);
      await precacheImage(provider, context);
    } catch (_) {
      // Einzelne kaputte Assets sollen den Rest nicht blockieren.
    }
  }
}

int thumbCacheWidth(BuildContext context, double logicalWidth) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalWidth * dpr).round().clamp(96, 1024);
}
