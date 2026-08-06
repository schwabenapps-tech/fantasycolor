import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';

/// Lädt alle SVG-Ausmalbilder aus `assets/coloring_pages/`.
/// Nach dem Umbenennen oder Hinzufügen von Dateien reicht ein App-Neustart.
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
            path.toLowerCase().endsWith('.svg'),
      )
      .toList()
    ..sort();

  final pages = paths.map(ColoringPage.fromAssetPath).toList();
  if (shuffle) {
    pages.shuffle(random ?? Random());
  }
  return List<ColoringPage>.unmodifiable(pages);
}
