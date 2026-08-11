import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';

/// Lädt alle PNG-Ausmalbilder aus `assets/coloring_pages/`.
Future<List<ColoringPage>> loadColoringPages({
  bool shuffle = true,
  Random? random,
}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where(
        (path) =>
            path.startsWith('assets/coloring_pages/') &&
            path.toLowerCase().endsWith('.png'),
      )
      .toList()
    ..sort();

  final pages = <ColoringPage>[];
  for (final path in paths) {
    final size = await _decodeImageSize(path);
    pages.add(
      ColoringPage.fromAssetPath(
        path,
        width: size.width.toDouble(),
        height: size.height.toDouble(),
      ),
    );
  }

  if (shuffle) {
    pages.shuffle(random ?? Random());
  }
  return List<ColoringPage>.unmodifiable(pages);
}

Future<({int width, int height})> _decodeImageSize(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final size = (width: image.width, height: image.height);
  image.dispose();
  return size;
}
