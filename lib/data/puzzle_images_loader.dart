import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import '../services/remote_pack_service.dart';
import 'asset_dimensions.dart';
import 'event_catalog.dart';
import 'event_tags.dart';

/// Bundle + Remote Puzzle-Gallery als Event-/Standard-Katalog.
Future<GalleryCatalog> loadPuzzleCatalog({
  bool shuffle = true,
  Random? random,
}) async {
  final pages = await loadPuzzleImages(shuffle: false, random: random);
  final tags = await EventTags.load();
  return tags.buildCatalog(
    pages,
    coloring: false,
    shuffleStandard: shuffle,
    random: random,
  );
}

/// Lädt alle Puzzle-Bilder aus Bundle + Remote-Packs.
Future<List<ColoringPage>> loadPuzzleImages({
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
            path.startsWith('assets/puzzle_images/') && _isImagePath(path),
      )
      .toList()
    ..sort();

  final bundlePages = paths.map(dimensions.pageFromPath).toList();
  final bundleKeys = {
    for (final path in paths) normalizeImageKey(path.split('/').last),
  };
  final remotePages = await RemotePackService.instance.puzzlePages(
    bundleSourceKeys: bundleKeys,
  );

  final byId = <String, ColoringPage>{
    for (final p in bundlePages) p.id: p,
    for (final p in remotePages) p.id: p,
  };

  return tags.prioritize(
    byId.values.toList(growable: false),
    featuredOrder: tags.featuredPuzzle,
    shuffleRest: shuffle,
    random: random,
  );
}

bool _isImagePath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp');
}
