import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import 'asset_dimensions.dart';
import 'event_catalog.dart';
import 'event_tags.dart';

/// Dateiname → Druckvorlagen-ID (gleiche Regel wie `scripts/sync_print_templates.py`).
String printTemplateIdFromSourceName(String sourceFileName) {
  var stem = sourceFileName.split('/').last;
  stem = stem.replaceAll(
    RegExp(r'\.(png|jpg|jpeg)$', caseSensitive: false),
    '',
  );
  stem = stem.toLowerCase();
  stem = stem.replaceAll(RegExp(r'[^a-z0-9\-]+'), '_');
  stem = stem.replaceAll(RegExp(r'_+'), '_');
  return stem.replaceAll(RegExp(r'^_|_$'), '');
}

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

/// Event-Hub (Halloween) vorne, Standard-Druckvorlagen getrennt dahinter.
Future<GalleryCatalog> loadPrintCatalog() async {
  final pages = await loadPrintTemplates(shuffle: false);
  final tags = await EventTags.load();
  final halloweenIds = await resolveHalloweenPrintIds(tags);
  final byId = {for (final p in pages) p.id: p};

  final active = <GallerySection>[];
  final past = <GallerySection>[];
  final claimed = <String>{};

  for (final event in tags.allEvents()) {
    if (event.isUpcoming()) continue;
    // Druckvorlagen folgen den Event-Ausmal-IDs über die Source-Map (Reihenfolge behalten).
    var eventPages = <ColoringPage>[
      for (final coloringId in event.coloringIds)
        if (halloweenIds[coloringId] != null &&
            byId.containsKey(halloweenIds[coloringId]!))
          byId[halloweenIds[coloringId]!]!,
    ];
    // Fallback: Halloween-Event ohne coloring_ids → alle gemappten Halloween-Prints.
    if (eventPages.isEmpty && event.id.toLowerCase().contains('halloween')) {
      final seen = <String>{};
      eventPages = [
        for (final printId in halloweenIds.values)
          if (seen.add(printId) && byId.containsKey(printId)) byId[printId]!,
      ];
    }
    if (eventPages.isEmpty) continue;
    for (final p in eventPages) {
      claimed.add(p.id);
    }
    final section = GallerySection(
      id: event.id,
      title: event.title,
      pages: List.unmodifiable(eventPages),
      isEvent: true,
      isActiveEvent: event.isActive(),
      isPastEvent: event.isPast(),
    );
    if (event.isPast()) {
      past.add(section);
    } else {
      active.add(section);
    }
  }

  final standardPages = [
    for (final p in pages)
      if (!claimed.contains(p.id)) p,
  ];

  return GalleryCatalog(
    activeEvents: List.unmodifiable(active),
    standard: GallerySection(
      id: 'standard',
      title: 'Gallery',
      pages: List.unmodifiable(standardPages),
    ),
    pastEvents: List.unmodifiable(past),
  );
}

/// Halloween Ausmal-ID → Druckvorlagen-ID.
Future<Map<String, String>> resolveHalloweenPrintIds(EventTags tags) async {
  final sourceMap = await _loadColoringSourceMap();
  final out = <String, String>{};
  for (final coloringId in tags.halloweenColoring) {
    final source = sourceMap[coloringId];
    if (source == null || source.isEmpty) continue;
    out[coloringId] = printTemplateIdFromSourceName(source);
  }
  return out;
}

Future<Set<String>> halloweenPrintTemplateIds() async {
  final tags = await EventTags.load();
  final mapped = await resolveHalloweenPrintIds(tags);
  return mapped.values.toSet();
}

Future<Map<String, String>> _loadColoringSourceMap() async {
  try {
    final raw = await rootBundle.loadString('assets/coloring_source_map.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in json.entries) e.key.toString(): e.value.toString(),
    };
  } catch (_) {
    return const {};
  }
}
