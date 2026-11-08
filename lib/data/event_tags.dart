import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import '../services/remote_pack_service.dart';
import 'event_catalog.dart';

/// Event-/Neu-Markierungen für Galerie-Reihenfolge und Badges.
class EventTags {
  EventTags._({
    required this.events,
    required this.halloweenColoring,
    required this.featuredColoring,
    required this.halloweenPuzzle,
    required this.featuredPuzzle,
    required this.newSinceColoring,
    required this.newSincePuzzle,
  });

  /// „NEW“-Badge verschwindet nach zwei Wochen.
  static const newBadgeDuration = Duration(days: 14);

  final List<ContentEvent> events;
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
      final events = <ContentEvent>[];
      final rawEvents = json['events'];
      if (rawEvents is List) {
        for (final item in rawEvents) {
          if (item is Map<String, dynamic>) {
            events.add(ContentEvent.fromJson(item));
          } else if (item is Map) {
            events.add(ContentEvent.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      _cache = EventTags._(
        events: events,
        halloweenColoring: _stringSet(json['halloween_coloring']),
        featuredColoring: _stringList(json['featured_coloring']),
        halloweenPuzzle: _stringSet(json['halloween_puzzle']),
        featuredPuzzle: _stringList(json['featured_puzzle']),
        newSinceColoring: _dateMap(json['new_since_coloring']),
        newSincePuzzle: _dateMap(json['new_since_puzzle']),
      );
    } catch (_) {
      _cache = EventTags._(
        events: const [],
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
      _isNew(newSinceColoring[id], now: now) ||
      RemotePackService.instance.isNewPage(id, now: now);

  bool isNewPuzzle(String id, {DateTime? now}) =>
      _isNew(newSincePuzzle[id], now: now) ||
      RemotePackService.instance.isNewPage(id, now: now);

  DateTime? coloringAddedAt(String id) => newSinceColoring[id];
  DateTime? puzzleAddedAt(String id) => newSincePuzzle[id];

  /// Zuletzt abgelaufenes Event (nach `ends_at`), sonst null.
  ContentEvent? lastPastEvent({DateTime? now}) {
    final past = [
      for (final e in allEvents())
        if (e.isPast(now: now)) e,
    ];
    if (past.isEmpty) return null;
    past.sort((a, b) {
      final ae = a.endsAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final be = b.endsAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return be.compareTo(ae);
    });
    return past.first;
  }

  /// Neueste zuerst — Bundle-`new_since_*` + Remote-Pack-Daten.
  List<ColoringPage> sortNewestFirst(
    List<ColoringPage> pages, {
    required bool coloring,
  }) {
    final sorted = List<ColoringPage>.from(pages);
    sorted.sort((a, b) {
      final da = addedAt(a.id, coloring: coloring);
      final db = addedAt(b.id, coloring: coloring);
      if (da == null && db == null) return a.id.compareTo(b.id);
      if (da == null) return 1;
      if (db == null) return -1;
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  /// Effektives „seit“-Datum für Sortierung / Neu-Logik.
  DateTime? addedAt(String id, {required bool coloring}) {
    final fromTags = coloring ? newSinceColoring[id] : newSincePuzzle[id];
    final fromRemote = RemotePackService.instance.pageAddedAt(id);
    if (fromTags == null) return fromRemote;
    if (fromRemote == null) return fromTags;
    return fromTags.isAfter(fromRemote) ? fromTags : fromRemote;
  }

  bool isEventPage(String id, {required bool coloring}) {
    for (final event in allEvents()) {
      if (event.idsFor(coloring: coloring).contains(id)) return true;
    }
    return false;
  }

  /// Bundle-Events + Remote-Pack-Events (Remote überschreibt gleiche ID).
  List<ContentEvent> allEvents() {
    final byId = <String, ContentEvent>{
      for (final e in events) e.id: e,
    };
    for (final remote in RemotePackService.instance.remoteEvents()) {
      final existing = byId[remote.id];
      if (existing == null) {
        byId[remote.id] = remote;
      } else {
        byId[remote.id] = ContentEvent(
          id: existing.id,
          title: remote.title.isNotEmpty ? remote.title : existing.title,
          startsAt: remote.startsAt ?? existing.startsAt,
          endsAt: remote.endsAt ?? existing.endsAt,
          coloringIds: {...existing.coloringIds, ...remote.coloringIds},
          puzzleIds: {...existing.puzzleIds, ...remote.puzzleIds},
        );
      }
    }
    return byId.values.toList(growable: false);
  }

  /// Baut aktive Event-Hubs → Standard → abgelaufene Event-Hubs.
  GalleryCatalog buildCatalog(
    List<ColoringPage> pages, {
    required bool coloring,
    bool shuffleStandard = true,
    Random? random,
  }) {
    final byId = {for (final p in pages) p.id: p};
    final claimed = <String>{};
    final active = <GallerySection>[];
    final past = <GallerySection>[];

    for (final event in allEvents()) {
      if (event.isUpcoming()) continue;
      final ids = event.idsFor(coloring: coloring);
      final eventPages = <ColoringPage>[
        for (final id in ids)
          if (byId.containsKey(id)) byId[id]!,
      ];
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

    final featuredOrder = coloring ? featuredColoring : featuredPuzzle;
    final restIds = byId.keys.where((id) => !claimed.contains(id)).toList();

    bool isNewId(String id) =>
        coloring ? isNewColoring(id) : isNewPuzzle(id);

    // Innerhalb von Event-Hubs ebenfalls neueste zuerst.
    for (var i = 0; i < active.length; i++) {
      final s = active[i];
      active[i] = GallerySection(
        id: s.id,
        title: s.title,
        pages: List.unmodifiable(sortNewestFirst(s.pages, coloring: coloring)),
        isEvent: s.isEvent,
        isActiveEvent: s.isActiveEvent,
        isPastEvent: s.isPastEvent,
      );
    }
    for (var i = 0; i < past.length; i++) {
      final s = past[i];
      past[i] = GallerySection(
        id: s.id,
        title: s.title,
        pages: List.unmodifiable(sortNewestFirst(s.pages, coloring: coloring)),
        isEvent: s.isEvent,
        isActiveEvent: s.isActiveEvent,
        isPastEvent: s.isPastEvent,
      );
    }

    // Standard: NEU zuerst → Featured → Rest.
    final newPages = sortNewestFirst(
      [
        for (final id in restIds)
          if (isNewId(id)) byId[id]!,
      ],
      coloring: coloring,
    );
    final newIds = {for (final p in newPages) p.id};
    final featuredPages = <ColoringPage>[
      for (final id in featuredOrder)
        if (restIds.contains(id) && !newIds.contains(id)) byId[id]!,
    ];
    final featuredIds = {for (final p in featuredPages) p.id};
    final rest = [
      for (final id in restIds)
        if (!newIds.contains(id) && !featuredIds.contains(id)) byId[id]!,
    ];
    if (shuffleStandard) {
      rest.shuffle(random ?? Random());
    } else {
      rest.sort((a, b) => a.id.compareTo(b.id));
    }

    return GalleryCatalog(
      activeEvents: List.unmodifiable(active),
      standard: GallerySection(
        id: 'standard',
        title: 'Gallery',
        pages: List.unmodifiable([...newPages, ...featuredPages, ...rest]),
      ),
      pastEvents: List.unmodifiable(past),
    );
  }

  static bool _isNew(DateTime? since, {DateTime? now}) {
    if (since == null) return false;
    final n = now ?? DateTime.now();
    final age = n.difference(since);
    return !age.isNegative && age <= newBadgeDuration;
  }

  /// Neu zuerst → Featured → Rest (optional gemischt).
  List<ColoringPage> prioritize(
    List<ColoringPage> pages, {
    required List<String> featuredOrder,
    bool shuffleRest = true,
    Random? random,
    bool coloring = true,
  }) {
    final byId = {for (final p in pages) p.id: p};
    final newPages = sortNewestFirst(
      [
        for (final p in pages)
          if (coloring ? isNewColoring(p.id) : isNewPuzzle(p.id)) p,
      ],
      coloring: coloring,
    );
    for (final p in newPages) {
      byId.remove(p.id);
    }
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
    return List<ColoringPage>.unmodifiable([...newPages, ...front, ...rest]);
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
