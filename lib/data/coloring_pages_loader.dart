import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import '../services/remote_pack_service.dart';
import 'asset_dimensions.dart';
import 'event_catalog.dart';
import 'event_tags.dart';

/// Lädt Bundle- + Remote-Ausmalbilder und baut Event-/Standard-Katalog.
Future<GalleryCatalog> loadColoringCatalog({
  bool shuffle = true,
  Random? random,
}) async {
  final pages = await loadColoringPages(shuffle: false, random: random);
  final tags = await EventTags.load();
  return tags.buildCatalog(
    pages,
    coloring: true,
    shuffleStandard: shuffle,
    random: random,
  );
}

/// Lädt alle PNG-Ausmalbilder aus Bundle + Remote-Packs.
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

  final bundlePages = paths.map(dimensions.pageFromPath).toList();
  final sourceKeys = await _coloringSourceKeys();
  final remotePages = await RemotePackService.instance.coloringPages(
    bundleSourceKeys: sourceKeys,
  );

  final byId = <String, ColoringPage>{
    for (final p in bundlePages) p.id: p,
    for (final p in remotePages) p.id: p,
  };

  final merged = byId.values.toList(growable: false);
  return tags.prioritize(
    merged,
    featuredOrder: tags.featuredColoring,
    shuffleRest: shuffle,
    random: random,
  );
}

Future<Set<String>> _coloringSourceKeys() async {
  try {
    final raw = await rootBundle.loadString('assets/coloring_source_map.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final value in json.values) normalizeImageKey(value.toString()),
    };
  } catch (_) {
    return {};
  }
}
