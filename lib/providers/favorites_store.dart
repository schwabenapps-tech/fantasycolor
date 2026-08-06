import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistierte Favoriten für Ausmalbilder (per Seiten-ID).
class FavoritesStore extends ChangeNotifier {
  FavoritesStore();

  static const _prefsKey = 'favorite_coloring_ids';

  final Set<String> _ids = <String>{};
  bool _ready = false;

  bool get isReady => _ready;

  Set<String> get ids => Set<String>.unmodifiable(_ids);

  bool isFavorite(String id) => _ids.contains(id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? const <String>[];
    _ids
      ..clear()
      ..addAll(stored);
    _ready = true;
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _ids.toList(growable: false));
  }
}
