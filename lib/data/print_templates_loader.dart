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

  // Nutzerfreundliche Titel — keine Roh-Dateinamen (z. B. chatgpt_…).
  final pages = <ColoringPage>[];
  for (var i = 0; i < paths.length; i++) {
    final base = dimensions.pageFromPath(paths[i]);
    pages.add(
      ColoringPage(
        id: base.id,
        title: 'Fairy Fantasy Color ${i + 1}',
        assetPath: base.assetPath,
        width: base.width,
        height: base.height,
      ),
    );
  }

  if (shuffle) {
    pages.shuffle(random ?? Random());
  }
  return List<ColoringPage>.unmodifiable(pages);
}
