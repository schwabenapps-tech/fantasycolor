import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 100 %-Ausmalbilder für Pixelart + Ad-Freischaltung + Sticker-Belohnung.
class PixelReadyStore extends ChangeNotifier {
  PixelReadyStore();

  static const hubCoverAsset = 'assets/images/pixelart_hub.png';

  static const _readyKey = 'pixel_ready_coloring_ids_v1';
  static const _unlockedKey = 'pixel_paint_unlocked_ids_v1';
  static const _stickerKey = 'pixel_sticker_rewarded_ids_v1';

  final Set<String> _ids = {};
  final Set<String> _unlocked = {};
  final Set<String> _stickerRewarded = {};
  bool _ready = false;

  bool get isReady => _ready;
  Set<String> get ids => Set.unmodifiable(_ids);
  bool isReadyFor(String id) => _ids.contains(id);
  bool isPaintUnlocked(String id) => _unlocked.contains(id);
  bool stickerRewarded(String id) => _stickerRewarded.contains(id);
  int get count => _ids.length;

  /// Pixel-Sterne-Rating (keine Währungs-Sterne).
  static int starRatingForFill(double fill) {
    if (fill >= 0.999) return 3;
    if (fill >= 0.80) return 2;
    if (fill >= 0.50) return 1;
    return 0;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(prefs.getStringList(_readyKey) ?? const []);
    _unlocked
      ..clear()
      ..addAll(prefs.getStringList(_unlockedKey) ?? const []);
    _stickerRewarded
      ..clear()
      ..addAll(prefs.getStringList(_stickerKey) ?? const []);
    _ready = true;
    notifyListeners();
  }

  Future<void> markReady(String id) async {
    if (id.isEmpty || _ids.contains(id)) return;
    _ids.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _readyKey,
      _ids.toList(growable: false)..sort(),
    );
    notifyListeners();
  }

  /// Nachträglich: fertige Ausmalbilder (ab 1★ / Daily) → Pixelart-Galerie.
  Future<void> syncFromCompletedColoring({
    required Iterable<String> progressIds,
    required int Function(String id) coloringRating,
    Iterable<String> extraIds = const [],
  }) async {
    if (!_ready) await load();
    var changed = false;
    void consider(String id) {
      if (id.isEmpty || _ids.contains(id)) return;
      _ids.add(id);
      changed = true;
    }

    for (final id in progressIds) {
      // Done/Daily ab ~1★ reicht — erscheint in Pixel Art und für Reuse-Dailys.
      if (coloringRating(id) >= 1) consider(id);
    }
    for (final id in extraIds) {
      consider(id);
    }
    if (!changed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _readyKey,
      _ids.toList(growable: false)..sort(),
    );
    notifyListeners();
  }

  Future<void> unlockPaint(String id) async {
    if (id.isEmpty || _unlocked.contains(id)) return;
    _unlocked.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _unlockedKey,
      _unlocked.toList(growable: false)..sort(),
    );
    notifyListeners();
  }

  Future<void> markStickerRewarded(String id) async {
    if (id.isEmpty || _stickerRewarded.contains(id)) return;
    _stickerRewarded.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _stickerKey,
      _stickerRewarded.toList(growable: false)..sort(),
    );
    notifyListeners();
  }
}
