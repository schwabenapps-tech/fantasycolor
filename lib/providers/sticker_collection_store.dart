import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/sticker_catalog.dart';

/// Persistierter Sticker-Besitz + Daily-Claim.
class StickerCollectionStore extends ChangeNotifier {
  StickerCollectionStore();

  static const _ownedKey = 'sticker_owned_ids_v1';
  static const _dailyClaimKey = 'sticker_daily_claim_day_v1';

  final Set<String> _owned = <String>{};
  StickerCatalog? _catalog;
  bool _ready = false;
  String? _lastDailyClaimDay;

  final _rng = Random();

  bool get isReady => _ready;
  StickerCatalog? get catalog => _catalog;
  int get ownedCount => _owned.length;
  int get totalCount => _catalog?.count ?? 0;
  bool get isComplete =>
      _catalog != null && _catalog!.count > 0 && _owned.length >= _catalog!.count;

  Set<String> get ownedIds => Set<String>.unmodifiable(_owned);

  bool owns(String id) => _owned.contains(id);

  Future<void> load() async {
    _catalog = await StickerCatalog.load();
    final prefs = await SharedPreferences.getInstance();
    _owned
      ..clear()
      ..addAll(prefs.getStringList(_ownedKey) ?? const <String>[]);
    // Ungültige IDs entfernen.
    final valid = _catalog!.stickers.map((s) => s.id).toSet();
    _owned.removeWhere((id) => !valid.contains(id));
    _lastDailyClaimDay = prefs.getString(_dailyClaimKey);
    _ready = true;
    notifyListeners();
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

  /// Puzzle belohnt: gemappten Sticker, sonst zufällig aus dem unverdienten Pool.
  Future<StickerEntry?> unlockForPuzzle(String puzzleId) async {
    await _ensureReady();
    final mapped = _catalog?.forPuzzleId(puzzleId);
    if (mapped != null) {
      final unlocked = await unlock(mapped.id);
      if (unlocked != null) return unlocked;
      // Schon besessen → trotzdem Belohnung aus dem Restpool.
    }
    final pool = unownedStickers();
    if (pool.isEmpty) return null;
    final pick = pool[_rng.nextInt(pool.length)];
    return unlock(pick.id);
  }

  /// Daily: wählt zufälligen unverdienten Sticker und markiert den Tag.
  Future<StickerEntry?> claimDailyRandom() async {
    if (!canClaimDaily) return null;
    final pool = unownedStickers();
    if (pool.isEmpty) return null;
    final pick = pool[_rng.nextInt(pool.length)];
    final unlocked = await unlock(pick.id);
    if (unlocked == null) return null;
    _lastDailyClaimDay = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyClaimKey, _lastDailyClaimDay!);
    notifyListeners();
    return unlocked;
  }
}
