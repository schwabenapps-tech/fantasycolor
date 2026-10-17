import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/sticker_catalog.dart';
import '../services/remote_pack_service.dart';

/// Persistierter Sticker-Besitz + Daily-Claim.
class StickerCollectionStore extends ChangeNotifier {
  StickerCollectionStore();

  static const _ownedKey = 'sticker_owned_ids_v1';
  static const _dailyClaimKey = 'sticker_daily_claim_day_v1';
  static const _coloringRewardedKey = 'sticker_coloring_rewarded_ids_v1';

  final Set<String> _owned = <String>{};
  final Set<String> _coloringRewarded = <String>{};
  StickerCatalog? _catalog;
  bool _ready = false;
  String? _lastDailyClaimDay;

  final _rng = Random();

  bool get isReady => _ready;
  StickerCatalog? get catalog => _catalog;

  /// Nur Stickers, die im aktuellen (gemergten) Katalog stehen.
  int get ownedCount {
    final cat = _catalog;
    if (cat == null) return 0;
    var n = 0;
    for (final s in cat.stickers) {
      if (_owned.contains(s.id)) n++;
    }
    return n;
  }

  int get totalCount => _catalog?.count ?? 0;
  bool get isComplete =>
      _catalog != null && _catalog!.count > 0 && ownedCount >= _catalog!.count;

  Set<String> get ownedIds => Set<String>.unmodifiable(_owned);

  bool owns(String id) => _owned.contains(id);

  Future<void> load() async {
    await _loadCatalogMerged();
    final prefs = await SharedPreferences.getInstance();
    _owned
      ..clear()
      ..addAll(prefs.getStringList(_ownedKey) ?? const <String>[]);
    _coloringRewarded
      ..clear()
      ..addAll(prefs.getStringList(_coloringRewardedKey) ?? const <String>[]);
    // Kein aggressives Prunen: Remote-IDs bleiben erhalten, falls Sync kurz fehlt.
    _lastDailyClaimDay = prefs.getString(_dailyClaimKey);
    _ready = true;
    notifyListeners();
  }

  /// Nach CDN-Sync: Katalog neu mergen (Owned bleibt).
  Future<void> reloadCatalog() async {
    StickerCatalog.clearCache();
    await _loadCatalogMerged();
    _ready = true;
    notifyListeners();
  }

  /// Test/Reset: alle freigeschalteten Stickers + Daily-Claim löschen.
  Future<void> resetCollection() async {
    await _ensureReady();
    _owned.clear();
    _coloringRewarded.clear();
    _lastDailyClaimDay = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ownedKey);
    await prefs.remove(_dailyClaimKey);
    await prefs.remove(_coloringRewardedKey);
    notifyListeners();
  }

  /// Pro Ausmalbild nur einmal Sticker-Belohnung (verhindert Farming).
  bool canRewardColoring(String coloringId) =>
      !_coloringRewarded.contains(coloringId);

  Future<void> markColoringRewarded(String coloringId) async {
    if (_coloringRewarded.contains(coloringId)) return;
    _coloringRewarded.add(coloringId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _coloringRewardedKey,
      _coloringRewarded.toList(growable: false)..sort(),
    );
    notifyListeners();
  }

  Future<void> _loadCatalogMerged() async {
    final remote = await RemotePackService.instance.remoteStickerEntries();
    StickerCatalog.clearCache();
    _catalog = await StickerCatalog.load(remote: remote);
  }

  String _todayKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  /// Daily noch verfügbar heute und Pool nicht leer.
  bool get canClaimDaily {
    if (!_ready || _catalog == null) return false;
    if (isComplete) return false;
    if (_lastDailyClaimDay == _todayKey()) return false;
    return unownedStickers().isNotEmpty;
  }

  List<StickerEntry> unownedStickers() {
    final cat = _catalog;
    if (cat == null) return const [];
    return [
      for (final s in cat.stickers)
        if (!_owned.contains(s.id)) s,
    ];
  }

  Future<void> _ensureReady() async {
    if (!_ready) await load();
  }

  /// Schaltet Sticker frei. Returns entry wenn neu, sonst null.
  Future<StickerEntry?> unlock(String stickerId) async {
    await _ensureReady();
    if (_owned.contains(stickerId)) return null;
    final entry = _catalog?.byId(stickerId);
    if (entry == null) return null;
    _owned.add(stickerId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_ownedKey, _owned.toList(growable: false)..sort());
    return entry;
  }

  Future<StickerEntry?> unlockForColoring(String coloringId) async {
    await _ensureReady();
    final entry = _catalog?.forColoringId(coloringId);
    if (entry == null) return null;
    return unlock(entry.id);
  }

  /// Bis zu [count] verschiedene noch nicht besessene Sticker zur Box-Auswahl.
  /// [prefer] landet bevorzugt in der Auswahl (z. B. gemapptes Motiv).
  List<StickerEntry> offerChoices({int count = 3, StickerEntry? prefer}) {
    final pool = unownedStickers();
    if (pool.isEmpty) return const [];
    final out = <StickerEntry>[];
    if (prefer != null && pool.any((s) => s.id == prefer.id)) {
      out.add(prefer);
    }
    final rest = [...pool]..shuffle(_rng);
    for (final s in rest) {
      if (out.length >= count) break;
      if (out.any((e) => e.id == s.id)) continue;
      out.add(s);
    }
    out.shuffle(_rng);
    return out;
  }

  List<StickerEntry> choicesForColoring(String coloringId) {
    final prefer = _catalog?.forColoringId(coloringId);
    return offerChoices(prefer: prefer);
  }

  /// Puzzle-Belohnung auf **jeder** Schwierigkeit (Easy/Medium/Pro).
  List<StickerEntry> choicesForPuzzle(String puzzleId) {
    final prefer = _catalog?.forPuzzleId(puzzleId);
    return offerChoices(prefer: prefer);
  }

  /// Puzzle-Belohnung auf **jeder** Schwierigkeit (Easy/Medium/Pro).
  /// Gemappter Sticker falls vorhanden, sonst zufällig aus dem unverdienten Pool.
  Future<StickerEntry?> unlockForPuzzle(String puzzleId) async {
    await _ensureReady();
    final choices = choicesForPuzzle(puzzleId);
    if (choices.isEmpty) {
      debugPrint('unlockForPuzzle: all stickers already owned');
      return null;
    }
    return unlock(choices.first.id);
  }

  /// Daily: freischalten der gewählten Box + Tag markieren.
  Future<StickerEntry?> claimDailyChoice(String stickerId) async {
    if (!canClaimDaily) return null;
    final unlocked = await unlock(stickerId);
    if (unlocked == null) return null;
    _lastDailyClaimDay = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyClaimKey, _lastDailyClaimDay!);
    notifyListeners();
    return unlocked;
  }

  /// Daily: wählt zufälligen unverdienten Sticker und markiert den Tag.
  Future<StickerEntry?> claimDailyRandom() async {
    if (!canClaimDaily) return null;
    final pool = unownedStickers();
    if (pool.isEmpty) return null;
    final pick = pool[_rng.nextInt(pool.length)];
    return claimDailyChoice(pick.id);
  }
}
