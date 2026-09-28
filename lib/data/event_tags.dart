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
  });

  final Set<String> halloweenColoring;
  final List<String> featuredColoring;
  final Set<String> halloweenPuzzle;
  final List<String> featuredPuzzle;

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
      );
    } catch (_) {
      _cache = EventTags._(
        halloweenColoring: const {},
        featuredColoring: const [],
        halloweenPuzzle: const {},
        featuredPuzzle: const [],
      );
    }
    return _cache!;
  }

  bool isHalloweenColoring(String id) => halloweenColoring.contains(id);
  bool isHalloweenPuzzle(String id) => halloweenPuzzle.contains(id);
  bool isFeaturedColoring(String id) => featuredColoring.contains(id);
  bool isFeaturedPuzzle(String id) => featuredPuzzle.contains(id);

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
}
