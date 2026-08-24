import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import 'asset_dimensions.dart';

/// Lädt alle Puzzle-Bilder aus `assets/puzzle_images/`.
Future<List<ColoringPage>> loadPuzzleImages({
  bool shuffle = true,
  Random? random,
}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final dimensions = await AssetDimensionsManifest.load();
  final paths = manifest
      .listAssets()
      .where(
        (path) =>
            path.startsWith('assets/puzzle_images/') && _isImagePath(path),
      )
      .toList()
    ..sort();

  final puzzles = paths.map(dimensions.pageFromPath).toList(growable: false);

  if (shuffle) {
    final list = List<ColoringPage>.from(puzzles);
    list.shuffle(random ?? Random());
    return List<ColoringPage>.unmodifiable(list);
  }
  return puzzles;
}

bool _isImagePath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg');
}
