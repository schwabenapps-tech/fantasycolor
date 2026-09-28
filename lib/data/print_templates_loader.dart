import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import 'asset_dimensions.dart';

/// Lädt die Druckvorlagen aus `assets/print_templates/`
/// (vereinfachte Ausmalbilder inkl. Halloween).
Future<List<ColoringPage>> loadPrintTemplates({
  bool shuffle = false,
  Random? random,
}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final dimensions = await AssetDimensionsManifest.load();

  bool isPngUnder(String path, String folder) =>
      path.startsWith(folder) && path.toLowerCase().endsWith('.png');

  final paths = manifest
      .listAssets()
      .where((path) => isPngUnder(path, 'assets/print_templates/'))
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
