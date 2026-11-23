import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/sticker_catalog.dart';
import '../services/advent_service.dart';
import '../services/remote_pack_service.dart';

/// Persistierter Sticker-Besitz + Daily-Claim.
///
/// Platzieren beim Ausmalen: besessen = frei; sonst Temp-Unlock pro Bild bis Done.
class StickerCollectionStore extends ChangeNotifier {
  StickerCollectionStore();

  static const _ownedKey = 'sticker_owned_ids_v1';
  static const _tempUnlockKey = 'sticker_temp_unlock_by_page_v1';
  static const _dailyClaimKey = 'sticker_daily_claim_day_v1';
  static const _coloringRewardedKey = 'sticker_coloring_rewarded_ids_v1';
  static const _puzzleRewardedKey = 'sticker_puzzle_rewarded_ids_v1';
  /// Jahr, in dem die einmalige Silvester-Box schon genutzt wurde.
  static const _silvesterBoxUsedYearKey = 'silvester_gift_box_used_year_v1';
  /// Legacy — wird beim Load gelesen und verworfen (Besitz reicht jetzt).
  static const _paintUnlockedKey = 'sticker_paint_unlocked_ids_v1';

  final Set<String> _owned = <String>{};
  /// pageId → temporär freigeschaltete Sticker-IDs (bis Done).
  final Map<String, Set<String>> _tempByPage = {};
  final Set<String> _coloringRewarded = <String>{};
  final Set<String> _puzzleRewarded = <String>{};
  StickerCatalog? _catalog;
  bool _ready = false;
  String? _lastDailyClaimDay;
  int? _silvesterBoxUsedYear;

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

  bool isTempUnlocked(String pageId, String stickerId) =>
      _tempByPage[pageId]?.contains(stickerId) ?? false;

  /// Beim Ausmalen immer nur temp für dieses Bild — Besitz allein reicht nicht.
  bool canPlaceInColoring(String id, {required String pageId}) =>
      isTempUnlocked(pageId, id);

  Future<void> load() async {
    await _loadCatalogMerged();
    final prefs = await SharedPreferences.getInstance();
    _owned
      ..clear()
      ..addAll(prefs.getStringList(_ownedKey) ?? const <String>[]);
    _tempByPage
      ..clear()
      ..addAll(_decodeTemp(prefs.getStringList(_tempUnlockKey)));
    _coloringRewarded
      ..clear()
      ..addAll(prefs.getStringList(_coloringRewardedKey) ?? const <String>[]);
    _puzzleRewarded
      ..clear()
      ..addAll(prefs.getStringList(_puzzleRewardedKey) ?? const <String>[]);
    // Legacy paint-unlock Prefs entfernen (Besitz = frei).
    if (prefs.containsKey(_paintUnlockedKey)) {
      await prefs.remove(_paintUnlockedKey);
    }
    _lastDailyClaimDay = prefs.getString(_dailyClaimKey);
    _silvesterBoxUsedYear = prefs.getInt(_silvesterBoxUsedYearKey);
    _ready = true;
    notifyListeners();
  }

  Map<String, Set<String>> _decodeTemp(List<String>? raw) {
    final out = <String, Set<String>>{};
    if (raw == null) return out;
    for (final line in raw) {
      final pipe = line.indexOf('|');
      if (pipe <= 0 || pipe >= line.length - 1) continue;
      final pageId = line.substring(0, pipe);
      final ids = line.substring(pipe + 1).split(',');
      out.putIfAbsent(pageId, () => <String>{});
      for (final id in ids) {
        if (id.isNotEmpty) out[pageId]!.add(id);
      }
    }
    return out;
  }

  List<String> _encodeTemp() {
    final out = <String>[];
    for (final e in _tempByPage.entries) {
      if (e.value.isEmpty) continue;
      final ids = e.value.toList(growable: false)..sort();
      out.add('${e.key}|${ids.join(',')}');
    }
    out.sort();
    return out;
  }

  Future<void> _persistTemp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_tempUnlockKey, _encodeTemp());
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
    _tempByPage.clear();
    _coloringRewarded.clear();
    _puzzleRewarded.clear();
    _lastDailyClaimDay = null;
    _silvesterBoxUsedYear = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ownedKey);
    await prefs.remove(_tempUnlockKey);
    await prefs.remove(_paintUnlockedKey);
    await prefs.remove(_dailyClaimKey);
    await prefs.remove(_coloringRewardedKey);
    await prefs.remove(_puzzleRewardedKey);
    await prefs.remove(_silvesterBoxUsedYearKey);
    notifyListeners();
  }

  /// Einmalige Silvester-Box am 31.12. noch verfügbar?
  bool get canUseSilvesterGiftBox {
    if (!AdventService.isNewYearsEve()) return false;
    final year = DateTime.now().year;
    return _silvesterBoxUsedYear != year;
  }

  /// Verbrauch der einmaligen Silvester-Box (sofort, damit Folge-Overlays klassisch bleiben).
  Future<bool> consumeSilvesterGiftBox() async {
    if (!canUseSilvesterGiftBox) return false;
    final year = DateTime.now().year;
    _silvesterBoxUsedYear = year;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_silvesterBoxUsedYearKey, year);
    notifyListeners();
    return true;
  }

  /// Pro Ausmal-Durchgang: nach Reset wieder belohnbar.
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

  /// Nach Reset eines Bildes: Sticker beim erneuten Fertigstellen wieder möglich.
  Future<void> clearColoringRewarded(String coloringId) async {
    if (!_coloringRewarded.remove(coloringId)) return;
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
    final packs = RemotePackService.instance;
    _catalog = await StickerCatalog.load(
      remote: remote,
      isNew: packs.isNewSticker,
      addedAt: packs.stickerAddedAt,
    );
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
    if (_lastDailyClaimDay == _todayKey()) return false;
    return dailyOfferPool().isNotEmpty;
  }

  List<StickerEntry> unownedStickers({StickerAlbumKind? album}) {
    final cat = _catalog;
    if (cat == null) return const [];
    return [
      for (final s in cat.stickers)
        if (!_owned.contains(s.id))
          if (album == null || s.album == album) s,
    ];
  }

  /// Daily-/Quest-/Completion-Pool: Klassik, plus Sondertage (1. Advent / Silvester).
  List<StickerEntry> dailyOfferPool() {
    final cat = _catalog;
    if (cat == null) return const [];

    if (AdventService.isNewYearsEve()) {
      final nye = [
        for (final id in AdventService.silvesterStickerIds)
          if (!_owned.contains(id))
            if (cat.byId(id) != null) cat.byId(id)!,
      ];
      if (nye.isNotEmpty) return nye;
    }

    final first = cat.byId(AdventService.firstAdventStickerId);
    final firstPending =
        first != null && !_owned.contains(first.id) && AdventService.usesChristmasGiftBox();

    // Am 1. Advent: exklusiv nur dieser Sticker mit der Weihnachtsbox.
    if (firstPending && AdventService.isFirstAdventDay()) {
      return [first];
    }

    final classic = unownedStickers(album: StickerAlbumKind.classic);
    // Bis 25.12. nachholen: 1.-Advent-Sticker bleibt in der Auswahl.
    if (firstPending) {
      return [first, ...classic];
    }
    return classic;
  }

  Future<void> _ensureReady() async {
    if (!_ready) await load();
  }

  /// Schaltet Sticker frei (Album/Geschenk). Returns entry wenn neu, sonst null.
  Future<StickerEntry?> unlock(
    String stickerId, {
    @Deprecated('Besitz reicht fürs Ausmalen') bool forPaint = false,
  }) async {
    await _ensureReady();
    final entry = _catalog?.byId(stickerId);
    if (entry == null) return null;
    final wasOwned = _owned.contains(stickerId);
    if (wasOwned) return null;
    _owned.add(stickerId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _ownedKey,
      _owned.toList(growable: false)..sort(),
    );
    notifyListeners();
    return entry;
  }

  /// Temporär für ein Ausmalbild (auch bei Album-Besitz — bis Done).
  Future<void> tempUnlockForPage(String pageId, String stickerId) async {
    await _ensureReady();
    final set = _tempByPage.putIfAbsent(pageId, () => <String>{});
    if (!set.add(stickerId)) return;
    await _persistTemp();
    notifyListeners();
  }

  /// Nach Done: Temp-Freischaltungen für dieses Bild zurücksetzen.
  Future<void> clearTempUnlocksForPage(String pageId) async {
    if (_tempByPage.remove(pageId) == null) return;
    await _persistTemp();
    notifyListeners();
  }

  /// Klassik-Album: dauerhafter Besitz per Sterne.
  Future<StickerEntry?> unlockWithStars(String stickerId) async {
    return unlock(stickerId);
  }

  /// Tray: besessen / temp zuerst, dann gesperrt.
  List<StickerEntry> paintTrayStickers({required String pageId}) {
    final cat = _catalog;
    if (cat == null) return const [];
    final free = <StickerEntry>[];
    final locked = <StickerEntry>[];
    for (final s in cat.stickers) {
      if (canPlaceInColoring(s.id, pageId: pageId)) {
        free.add(s);
      } else {
        locked.add(s);
      }
    }
    return [...free, ...locked];
  }

  Future<StickerEntry?> unlockForColoring(String coloringId) async {
    await _ensureReady();
    final entry = _catalog?.forColoringId(coloringId);
    if (entry == null) return null;
    return unlock(entry.id);
  }

  /// Bis zu [count] verschiedene noch nicht besessene Sticker zur Box-Auswahl.
  /// [prefer] landet bevorzugt in der Auswahl (z. B. gemapptes Motiv).
  /// Winter-Album nur an Sondertagen (1. Advent / Silvester) — sonst Klassik.
  List<StickerEntry> offerChoices({int count = 3, StickerEntry? prefer}) {
    final pool = dailyOfferPool();
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
    // Gemapptes Motiv nur, wenn es im Daily-Pool liegt (kein Winter-Leak).
    final pool = dailyOfferPool();
    final okPrefer =
        prefer != null && pool.any((s) => s.id == prefer.id) ? prefer : null;
    return offerChoices(prefer: okPrefer);
  }

  /// Pro Ausmal-/Puzzle-Motiv: Sticker nur einmal (bis Album-Reset).
  bool canRewardPuzzle(String puzzleId) => !_puzzleRewarded.contains(puzzleId);

  Future<void> markPuzzleRewarded(String puzzleId) async {
    if (_puzzleRewarded.contains(puzzleId)) return;
    _puzzleRewarded.add(puzzleId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _puzzleRewardedKey,
      _puzzleRewarded.toList(growable: false)..sort(),
    );
    notifyListeners();
  }

  /// Puzzle-Belohnung (UI: nur Pro/Expert). Gemappter Sticker bevorzugt.
  List<StickerEntry> choicesForPuzzle(String puzzleId) {
    final prefer = _catalog?.forPuzzleId(puzzleId);
    final pool = dailyOfferPool();
    final okPrefer =
        prefer != null && pool.any((s) => s.id == prefer.id) ? prefer : null;
    return offerChoices(prefer: okPrefer);
  }

  /// Sofort-Unlock für Puzzle (ohne Box-Wahl).
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
    final pool = dailyOfferPool();
    if (pool.isEmpty) return null;
    final pick = pool[_rng.nextInt(pool.length)];
    return claimDailyChoice(pick.id);
  }
}
