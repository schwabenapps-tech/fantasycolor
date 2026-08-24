import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import 'asset_dimensions.dart';

/// Lädt alle PNG-Ausmalbilder aus `assets/coloring_pages/`.
Future<List<ColoringPage>> loadColoringPages({
  bool shuffle = true,
  Random? random,
}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final dimensions = await AssetDimensionsManifest.load();
  final paths = manifest
      .listAssets()
      .where(
        (path) =>
            path.startsWith('assets/coloring_pages/') &&
            path.toLowerCase().endsWith('.png'),
      )
      .toList()
    ..sort();

  final pages = paths.map(dimensions.pageFromPath).toList(growable: false);

  if (shuffle) {
    final list = List<ColoringPage>.from(pages);
    list.shuffle(random ?? Random());
    return List<ColoringPage>.unmodifiable(list);
  }
  return pages;
}
