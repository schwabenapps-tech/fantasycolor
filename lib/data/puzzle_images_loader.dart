import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';

/// Lädt alle Puzzle-Bilder aus `assets/puzzle_images/`.
Future<List<ColoringPage>> loadPuzzleImages({
  bool shuffle = true,
  Random? random,
}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where(
        (path) =>
            path.startsWith('assets/puzzle_images/') &&
            _isImagePath(path),
      )
      .toList()
    ..sort();

  final puzzles = <ColoringPage>[];
  for (final path in paths) {
    final size = await _decodeImageSize(path);
    puzzles.add(
      ColoringPage.fromAssetPath(
        path,
        width: size.width.toDouble(),
        height: size.height.toDouble(),
      ),
    );
  }

  if (shuffle) {
    puzzles.shuffle(random ?? Random());
  }
  return List<ColoringPage>.unmodifiable(puzzles);
}

bool _isImagePath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg');
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
