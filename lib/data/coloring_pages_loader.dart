import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import 'asset_dimensions.dart';
import 'event_tags.dart';

/// Lädt alle PNG-Ausmalbilder aus `assets/coloring_pages/`.
///
/// Featured/Halloween stehen immer vorne; der Rest wird gemischt.
Future<List<ColoringPage>> loadColoringPages({
  bool shuffle = true,
  Random? random,
}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final dimensions = await AssetDimensionsManifest.load();
  final tags = await EventTags.load();
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
  return tags.prioritize(
    pages,
    featuredOrder: tags.featuredColoring,
    shuffleRest: shuffle,
    random: random,
  );
}
