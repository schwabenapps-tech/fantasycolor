import 'dart:convert';

import 'package:flutter/services.dart';

/// Ein Sticker im Sammelalbum.
class StickerEntry {
  const StickerEntry({
    required this.id,
    required this.assetPath,
    this.coloringId,
    this.puzzleId,
  });

  final String id;
  /// Bundle (`assets/…`) oder lokale Datei (Remote-Pack).
  final String assetPath;
  final String? coloringId;
  final String? puzzleId;

  factory StickerEntry.fromJson(Map<String, dynamic> json) {
    return StickerEntry(
      id: json['id'] as String,
      assetPath: json['asset'] as String,
      coloringId: json['coloringId'] as String?,
      puzzleId: json['puzzleId'] as String?,
    );
  }
}

/// Lädt [assets/sticker_catalog.json] und merged optional Remote-Einträge.
class StickerCatalog {
  StickerCatalog._(this.stickers);

  final List<StickerEntry> stickers;

  static StickerCatalog? _cached;

  static void clearCache() {
    _cached = null;
  }

  static Future<StickerCatalog> load({
    List<StickerEntry> remote = const [],
  }) async {
    final cached = _cached;
    if (cached != null && remote.isEmpty) return cached;
    final bundle = await _loadBundle();
    return _cached = merge(bundle, remote);
  }

  static Future<List<StickerEntry>> _loadBundle() async {
    final raw = await rootBundle.loadString('assets/sticker_catalog.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (map['stickers'] as List<dynamic>)
        .map((e) => StickerEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Bundle zuerst; Remote mit gleicher `id` ersetzt das Asset; neue IDs ans Ende.
  static StickerCatalog merge(
    List<StickerEntry> bundle,
    List<StickerEntry> remote,
  ) {
    if (remote.isEmpty) return StickerCatalog._(List.unmodifiable(bundle));
    final byId = <String, StickerEntry>{
      for (final s in bundle) s.id: s,
    };
    final order = <String>[for (final s in bundle) s.id];
    for (final s in remote) {
      if (byId.containsKey(s.id)) {
        byId[s.id] = s;
      } else {
        byId[s.id] = s;
        order.add(s.id);
      }
    }
    return StickerCatalog._([
      for (final id in order) byId[id]!,
    ]);
  }

  StickerEntry? byId(String id) {
    for (final s in stickers) {
      if (s.id == id) return s;
    }
    return null;
  }

  StickerEntry? forColoringId(String coloringId) {
    for (final s in stickers) {
      if (s.coloringId == coloringId) return s;
    }
    return null;
  }

  StickerEntry? forPuzzleId(String puzzleId) {
    for (final s in stickers) {
      if (s.puzzleId == puzzleId) return s;
    }
    // Fallback: gleiche ID wie Ausmalen, wenn Puzzle aus bemaltem Motiv kommt.
    return forColoringId(puzzleId);
  }

  int get count => stickers.length;
}
