import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fertig ausgemalte Bilder für Dot Art + Ad-Freischaltung + Sticker-Belohnung.
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

  /// Wie normales Ausmalen: 50 % / 80 % / 100 % → 1★ / 2★ / 3★.
  static int starRatingForFill(double fill) {
    if (fill >= 1.0) return 3;
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
    await _persistReady();
    notifyListeners();
  }

  /// Nach Ausmal-Reset / leerem PNG — aus Dot-Art-Galerie entfernen.
  Future<void> revokeReady(String id) async {
    if (id.isEmpty || !_ids.contains(id)) return;
    _ids.remove(id);
    await _persistReady();
    notifyListeners();
  }

  /// Nur Bilder mit gespeichertem Ausmal-PNG bleiben / werden ready.
  ///
  /// Neu aufnehmen wie Done: 3★ oder Daily (`extraIds`). Bereits ready bleibt,
  /// solange Progress existiert (Daily soll nach Tageswechsel nutzbar bleiben).
  /// Ohne Progress (z. B. Reset) fliegen IDs raus — zusammen mit
  /// `clearColoringRating` verhindert das Re-Ready nach wenig Neu-Malen.
  Future<void> syncFromCompletedColoring({
    required Iterable<String> progressIds,
    required int Function(String id) coloringRating,
    Iterable<String> extraIds = const [],
  }) async {
    if (!_ready) await load();
    final progressSet = progressIds.toSet();
    final extraSet = extraIds.toSet();
    var changed = false;

    bool qualifiesForAdd(String id) =>
        coloringRating(id) >= 3 || extraSet.contains(id);

    for (final id in progressSet) {
      if (id.isEmpty || _ids.contains(id)) continue;
      if (qualifiesForAdd(id)) {
        _ids.add(id);
        changed = true;
      }
    }

    // Nur ohne PNG entfernen — nicht wegen Rating < 3 (Daily-Reuse).
    final stale = [
      for (final id in _ids)
        if (!progressSet.contains(id)) id,
    ];
    for (final id in stale) {
      _ids.remove(id);
      changed = true;
    }

    if (!changed) return;
    await _persistReady();
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

  Future<void> _persistReady() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _readyKey,
      _ids.toList(growable: false)..sort(),
    );
  }
}
