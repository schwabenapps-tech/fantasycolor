import 'dart:convert';

import 'package:flutter/services.dart';

import 'event_catalog.dart';

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
    bool Function(String id)? isNew,
    DateTime? Function(String id)? addedAt,
  }) async {
    final cached = _cached;
    if (cached != null && remote.isEmpty) return cached;
    final bundle = await _loadBundle();
    return _cached = merge(
      bundle,
      remote,
      isNew: isNew,
      addedAt: addedAt,
    );
  }

  static Future<List<StickerEntry>> _loadBundle() async {
    final raw = await rootBundle.loadString('assets/sticker_catalog.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (map['stickers'] as List<dynamic>)
        .map((e) => StickerEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Bundle-Basis; Remote mit gleicher `id` ersetzt das Asset.
  /// **Neue** Remote-Stickers kommen an den Anfang (neueste zuerst).
  /// Remote-Motive, die schon im Bundle sind (Dateiname-Key), werden übersprungen.
  static StickerCatalog merge(
    List<StickerEntry> bundle,
    List<StickerEntry> remote, {
    bool Function(String id)? isNew,
    DateTime? Function(String id)? addedAt,
  }) {
    if (remote.isEmpty) return StickerCatalog._(List.unmodifiable(bundle));

    final byId = <String, StickerEntry>{
      for (final s in bundle) s.id: s,
    };
    final bundleKeys = <String>{
      for (final s in bundle) normalizeImageKey(s.assetPath),
    };

    final newRemote = <StickerEntry>[];
    final otherRemote = <StickerEntry>[];

    for (final s in remote) {
      final key = normalizeImageKey(s.assetPath);
      if (!byId.containsKey(s.id) && bundleKeys.contains(key)) {
        continue;
      }
      if (byId.containsKey(s.id)) {
        byId[s.id] = s;
        continue;
      }
      byId[s.id] = s;
      bundleKeys.add(key);
      final fresh = isNew?.call(s.id) ?? true;
      if (fresh) {
        newRemote.add(s);
      } else {
        otherRemote.add(s);
      }
    }

    int byAddedAt(StickerEntry a, StickerEntry b) {
      final da = addedAt?.call(a.id);
      final db = addedAt?.call(b.id);
      if (da == null && db == null) return b.id.compareTo(a.id);
      if (da == null) return 1;
      if (db == null) return -1;
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    }

    newRemote.sort(byAddedAt);
    otherRemote.sort(byAddedAt);

    final order = <String>[
      for (final s in newRemote) s.id,
      for (final s in bundle) s.id,
      for (final s in otherRemote) s.id,
    ];

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
