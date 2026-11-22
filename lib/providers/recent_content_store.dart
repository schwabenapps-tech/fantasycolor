import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'favorites_store.dart';

/// Heute geöffnete Ausmal-/Puzzle-Motive für Home „Zuletzt benutzt“.
///
/// Nur für den aktuellen Kalendertag — am nächsten Tag wieder leer.
class RecentContentStore extends ChangeNotifier {
  RecentContentStore();

  static const _key = 'recent_content_entries_v2';
  static const _dayKeyPrefs = 'recent_content_day_v2';
  static const maxItems = 24;

  /// Alte 14-Tage-Persistenz aufräumen.
  static const _legacyKey = 'recent_content_entries_v1';
  static const _legacyTouchedKey = 'recent_content_touched_at_v1';

  final List<RecentContentEntry> _entries = <RecentContentEntry>[];
  bool _ready = false;

  bool get isReady => _ready;

  List<RecentContentEntry> entries() =>
      List<RecentContentEntry>.unmodifiable(_entries);

  static String _calendarDay([DateTime? now]) {
    final d = now ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _clearDay(SharedPreferences prefs, String today) async {
    _entries.clear();
    await prefs.remove(_key);
    await prefs.setString(_dayKeyPrefs, today);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Legacy-Keys entfernen (kein Übernehmen über den Tag hinaus).
    await prefs.remove(_legacyKey);
    await prefs.remove(_legacyTouchedKey);

    final today = _calendarDay();
    final storedDay = prefs.getString(_dayKeyPrefs);
    if (storedDay != today) {
      await _clearDay(prefs, today);
      _ready = true;
      notifyListeners();
      return;
    }

    final raw = prefs.getStringList(_key) ?? const <String>[];
    _entries
      ..clear()
      ..addAll([
        for (final line in raw)
          if (RecentContentEntry.tryParse(line) case final e?) e,
      ]);

    _ready = true;
    notifyListeners();
  }

  Future<void> record(String id, {required FavoriteKind kind}) async {
    if (id.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _calendarDay();
    final storedDay = prefs.getString(_dayKeyPrefs);
    if (storedDay != today) {
      await _clearDay(prefs, today);
    }

    _entries.removeWhere((e) => e.id == id && e.kind == kind);
    _entries.insert(0, RecentContentEntry(id: id, kind: kind));
    while (_entries.length > maxItems) {
      _entries.removeLast();
    }
    notifyListeners();
    await prefs.setStringList(
      _key,
      [for (final e in _entries) e.encode()],
    );
    await prefs.setString(_dayKeyPrefs, today);
  }
}

class RecentContentEntry {
  const RecentContentEntry({
    required this.id,
    required this.kind,
  });

  final String id;
  final FavoriteKind kind;

  String encode() =>
      '${kind == FavoriteKind.coloring ? 'c' : 'p'}:$id';

  static RecentContentEntry? tryParse(String raw) {
    final i = raw.indexOf(':');
    if (i <= 0 || i >= raw.length - 1) return null;
    final prefix = raw.substring(0, i);
    final id = raw.substring(i + 1);
    if (id.isEmpty) return null;
    final kind = switch (prefix) {
      'c' => FavoriteKind.coloring,
      'p' => FavoriteKind.puzzle,
      _ => null,
    };
    if (kind == null) return null;
    return RecentContentEntry(id: id, kind: kind);
  }
}
