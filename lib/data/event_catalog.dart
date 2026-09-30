import 'dart:convert';

import '../models/coloring_page.dart';

/// Ein Event-Hub innerhalb Ausmalen/Puzzle (aktiv vorne, abgelaufen hinten).
class ContentEvent {
  const ContentEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.coloringIds = const {},
    this.puzzleIds = const {},
  });

  final String id;
  final String title;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final Set<String> coloringIds;
  final Set<String> puzzleIds;

  bool isActive({DateTime? now}) {
    final n = _dateOnly(now ?? DateTime.now());
    if (startsAt != null && n.isBefore(_dateOnly(startsAt!))) return false;
    if (endsAt != null && n.isAfter(_dateOnly(endsAt!))) return false;
    // Ohne Daten: wenn IDs da sind, als aktiv behandeln (laufendes Event).
    return true;
  }

  bool isPast({DateTime? now}) {
    if (endsAt == null) return false;
    final n = _dateOnly(now ?? DateTime.now());
    return n.isAfter(_dateOnly(endsAt!));
  }

  bool isUpcoming({DateTime? now}) {
    if (startsAt == null) return false;
    final n = _dateOnly(now ?? DateTime.now());
    return n.isBefore(_dateOnly(startsAt!));
  }

  Set<String> idsFor({required bool coloring}) =>
      coloring ? coloringIds : puzzleIds;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime? parseDate(Object? raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  factory ContentEvent.fromJson(Map<String, dynamic> json) {
    return ContentEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Event',
      startsAt: parseDate(json['starts_at']),
      endsAt: parseDate(json['ends_at']),
      coloringIds: _stringSet(json['coloring_ids']),
      puzzleIds: _stringSet(json['puzzle_ids']),
    );
  }

  static Set<String> _stringSet(Object? value) {
    if (value is! List) return {};
    return {for (final e in value) e.toString()};
  }
}

/// Abschnitt in der Galerie: Event-Hub oder Standard-Gallery.
class GallerySection {
  const GallerySection({
    required this.id,
    required this.title,
    required this.pages,
    this.isEvent = false,
    this.isActiveEvent = false,
    this.isPastEvent = false,
  });

  final String id;
  final String title;
  final List<ColoringPage> pages;
  final bool isEvent;
  final bool isActiveEvent;
  final bool isPastEvent;
}

/// Aktive Events → Standard → abgelaufene Events.
class GalleryCatalog {
  const GalleryCatalog({
    required this.activeEvents,
    required this.standard,
    required this.pastEvents,
  });

  final List<GallerySection> activeEvents;
  final GallerySection standard;
  final List<GallerySection> pastEvents;

  List<GallerySection> get orderedSections => [
        ...activeEvents,
        if (standard.pages.isNotEmpty) standard,
        ...pastEvents,
      ];

  List<ColoringPage> get allPages => [
        for (final s in orderedSections) ...s.pages,
      ];

  bool get isEmpty => orderedSections.every((s) => s.pages.isEmpty);
}

String normalizeImageKey(String name) {
  var stem = name.split('/').last;
  stem = stem.replaceAll(RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false), '');
  stem = stem.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  stem = stem.replaceAll(RegExp(r'_+'), '_');
  return stem.replaceAll(RegExp(r'^_|_$'), '');
}

/// Debug/Serialize helper.
String encodeEventsPreview(List<ContentEvent> events) =>
    jsonEncode([for (final e in events) e.id]);
