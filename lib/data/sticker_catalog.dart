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

/// Lädt [assets/sticker_catalog.json].
class StickerCatalog {
  StickerCatalog._(this.stickers);

  final List<StickerEntry> stickers;

  static StickerCatalog? _cached;

  static Future<StickerCatalog> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/sticker_catalog.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = (map['stickers'] as List<dynamic>)
        .map((e) => StickerEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _cached = StickerCatalog._(list);
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
