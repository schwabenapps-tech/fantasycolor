import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'favorites_store.dart';

/// Zuletzt geöffnete Ausmal-/Puzzle-Motive für Home „Zuletzt benutzt“.
///
/// Nach [expiry] ohne Nutzung (kein neues Öffnen) wird die Liste geleert.
class RecentContentStore extends ChangeNotifier {
  RecentContentStore();

  static const _key = 'recent_content_entries_v1';
  static const _touchedKey = 'recent_content_touched_at_v1';
  static const maxItems = 24;

  /// Lange ungenutzt → Abschnitt leer, bis wieder etwas geöffnet wird.
  static const expiry = Duration(days: 14);

  final List<RecentContentEntry> _entries = <RecentContentEntry>[];
  bool _ready = false;

  bool get isReady => _ready;

  List<RecentContentEntry> entries() =>
      List<RecentContentEntry>.unmodifiable(_entries);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final touchedMs = prefs.getInt(_touchedKey);

    if (touchedMs != null && now - touchedMs >= expiry.inMilliseconds) {
      _entries.clear();
      await prefs.remove(_key);
      await prefs.remove(_touchedKey);
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

    // Upgrade ohne Timestamp: nicht sofort löschen, Ablauf ab jetzt.
    if (_entries.isNotEmpty && touchedMs == null) {
      await prefs.setInt(_touchedKey, now);
    }

    _ready = true;
    notifyListeners();
  }

  Future<void> record(String id, {required FavoriteKind kind}) async {
    if (id.trim().isEmpty) return;
    _entries.removeWhere((e) => e.id == id && e.kind == kind);
    _entries.insert(0, RecentContentEntry(id: id, kind: kind));
    while (_entries.length > maxItems) {
      _entries.removeLast();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setStringList(
      _key,
      [for (final e in _entries) e.encode()],
    );
    await prefs.setInt(_touchedKey, now);
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
