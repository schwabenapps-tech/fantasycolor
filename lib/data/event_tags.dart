import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';

/// Event-/Neu-Markierungen für Galerie-Reihenfolge und Badges.
class EventTags {
  EventTags._({
    required this.halloweenColoring,
    required this.featuredColoring,
    required this.halloweenPuzzle,
    required this.featuredPuzzle,
    required this.newSinceColoring,
    required this.newSincePuzzle,
  });

  /// „NEU“-Badge nur so lange sichtbar (Sync setzt das Datum).
  static const newBadgeDuration = Duration(days: 7);

  final Set<String> halloweenColoring;
  final List<String> featuredColoring;
  final Set<String> halloweenPuzzle;
  final List<String> featuredPuzzle;

  /// id → ISO-Datum (YYYY-MM-DD), ab dem das Motiv als neu gilt.
  final Map<String, DateTime> newSinceColoring;
  final Map<String, DateTime> newSincePuzzle;

  static EventTags? _cache;

  static Future<EventTags> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/event_tags.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _cache = EventTags._(
        halloweenColoring: _stringSet(json['halloween_coloring']),
        featuredColoring: _stringList(json['featured_coloring']),
        halloweenPuzzle: _stringSet(json['halloween_puzzle']),
        featuredPuzzle: _stringList(json['featured_puzzle']),
        newSinceColoring: _dateMap(json['new_since_coloring']),
        newSincePuzzle: _dateMap(json['new_since_puzzle']),
      );
    } catch (_) {
      _cache = EventTags._(
        halloweenColoring: const {},
        featuredColoring: const [],
        halloweenPuzzle: const {},
        featuredPuzzle: const [],
        newSinceColoring: const {},
        newSincePuzzle: const {},
      );
    }
    return _cache!;
  }

  /// Nur für Tests / Hot-Reload nach Asset-Update.
  static void clearCache() => _cache = null;

  bool isHalloweenColoring(String id) => halloweenColoring.contains(id);
  bool isHalloweenPuzzle(String id) => halloweenPuzzle.contains(id);
  bool isFeaturedColoring(String id) => featuredColoring.contains(id);
  bool isFeaturedPuzzle(String id) => featuredPuzzle.contains(id);

  bool isNewColoring(String id, {DateTime? now}) =>
      _isNew(newSinceColoring[id], now: now);

  bool isNewPuzzle(String id, {DateTime? now}) =>
      _isNew(newSincePuzzle[id], now: now);

  static bool _isNew(DateTime? since, {DateTime? now}) {
    if (since == null) return false;
    final n = now ?? DateTime.now();
    final age = n.difference(since);
    return !age.isNegative && age <= newBadgeDuration;
  }

  /// Featured zuerst (Reihenfolge aus JSON), Rest optional gemischt.
  List<ColoringPage> prioritize(
    List<ColoringPage> pages, {
    required List<String> featuredOrder,
    bool shuffleRest = true,
    Random? random,
  }) {
    final byId = {for (final p in pages) p.id: p};
    final front = <ColoringPage>[
      for (final id in featuredOrder)
        if (byId.containsKey(id)) byId.remove(id)!,
    ];
    final rest = byId.values.toList();
    if (shuffleRest) {
      rest.shuffle(random ?? Random());
    } else {
      rest.sort((a, b) => a.id.compareTo(b.id));
    }
    return List<ColoringPage>.unmodifiable([...front, ...rest]);
  }

  static Set<String> _stringSet(Object? value) {
    if (value is! List) return {};
    return {for (final e in value) e.toString()};
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [for (final e in value) e.toString()];
  }

  static Map<String, DateTime> _dateMap(Object? value) {
    if (value is! Map) return const {};
    final out = <String, DateTime>{};
    value.forEach((key, raw) {
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) {
        out[key.toString()] = DateTime(parsed.year, parsed.month, parsed.day);
      }
    });
    return Map.unmodifiable(out);
  }
}
