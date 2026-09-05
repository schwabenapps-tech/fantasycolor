import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import 'asset_dimensions.dart';

/// Lädt alle Druckvorlagen:
/// - ausführlichere Motive aus `assets/print_templates/`
/// - einfachere Ausmalbilder aus `assets/coloring_pages/`
Future<List<ColoringPage>> loadPrintTemplates({
  bool shuffle = false,
  Random? random,
}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final dimensions = await AssetDimensionsManifest.load();

  bool isPngUnder(String path, String folder) =>
      path.startsWith(folder) && path.toLowerCase().endsWith('.png');

  final detailed = manifest
      .listAssets()
      .where((path) => isPngUnder(path, 'assets/print_templates/'))
      .toList()
    ..sort();

  final simple = manifest
      .listAssets()
      .where((path) => isPngUnder(path, 'assets/coloring_pages/'))
      .toList()
    ..sort();

  // Erst die klassischen Vorlagen, dann die einfacheren Ausmalbilder.
  final paths = [...detailed, ...simple];
  final pages = paths.map(dimensions.pageFromPath).toList(growable: false);

  if (shuffle) {
    final list = List<ColoringPage>.from(pages);
    list.shuffle(random ?? Random());
    return List<ColoringPage>.unmodifiable(list);
  }
  return pages;
}
