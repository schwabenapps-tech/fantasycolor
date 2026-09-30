import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FavoriteKind { coloring, puzzle }

/// Persistierte Favorites getrennt für Ausmalen und Puzzle.
/// Neu hinzugefügte Einträge stehen vorn (zuletzt gespeichert zuerst).
class FavoritesStore extends ChangeNotifier {
  FavoritesStore();

  static const _coloringKey = 'favorite_coloring_ids_v2';
  static const _puzzleKey = 'favorite_puzzle_ids_v2';
  static const _legacyKey = 'favorite_coloring_ids';

  final List<String> _coloringIds = <String>[];
  final List<String> _puzzleIds = <String>[];
  bool _ready = false;

  bool get isReady => _ready;

  List<String> coloringIds() => List<String>.unmodifiable(_coloringIds);

  List<String> puzzleIds() => List<String>.unmodifiable(_puzzleIds);

  bool isFavorite(String id, {required FavoriteKind kind}) =>
      _listFor(kind).contains(id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _coloringIds
      ..clear()
      ..addAll(prefs.getStringList(_coloringKey) ?? const <String>[]);
    _puzzleIds
      ..clear()
      ..addAll(prefs.getStringList(_puzzleKey) ?? const <String>[]);

    // Migrate older single-list favorites into coloring.
    if (_coloringIds.isEmpty) {
      final legacy = prefs.getStringList(_legacyKey) ?? const <String>[];
      if (legacy.isNotEmpty) {
        _coloringIds.addAll(legacy);
        await prefs.setStringList(
          _coloringKey,
          _coloringIds.toList(growable: false),
        );
      }
    }

    _ready = true;
    notifyListeners();
  }

  Future<void> toggle(String id, {required FavoriteKind kind}) async {
    final list = _listFor(kind);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.insert(0, id);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      kind == FavoriteKind.coloring ? _coloringKey : _puzzleKey,
      list.toList(growable: false),
    );
  }

  List<String> _listFor(FavoriteKind kind) => switch (kind) {
        FavoriteKind.coloring => _coloringIds,
        FavoriteKind.puzzle => _puzzleIds,
      };
}
