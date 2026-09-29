import 'package:flutter/material.dart';

import 'image_source.dart';

/// Precache für Bundle-Assets und heruntergeladene Pack-Dateien.
Future<void> precacheAssetImages(
  BuildContext context,
  Iterable<String> assetPaths, {
  int? cacheWidth,
}) {
  return precacheImagePaths(context, assetPaths, cacheWidth: cacheWidth);
}

int thumbCacheWidth(BuildContext context, double logicalWidth) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalWidth * dpr).round().clamp(96, 1024);
}
