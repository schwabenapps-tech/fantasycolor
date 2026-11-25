import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/star_economy.dart';
import '../services/advent_service.dart';
import 'favorites_store.dart';
import 'sticker_collection_store.dart';

/// Sterne-Guthaben + dauerhafte Freischaltungen + Completion-Ratings.
class StarWalletStore extends ChangeNotifier {
  StarWalletStore();

  static const _balanceKey = 'star_wallet_balance_v1';
  static const _unlockedColoringKey = 'star_unlocked_coloring_v1';
  static const _unlockedPuzzleKey = 'star_unlocked_puzzle_v1';
  static const _coloringRatingKey = 'star_coloring_rating_v1';
  static const _puzzleRewardedKey = 'star_puzzle_rewarded_v1';
  static const _puzzleRatingKey = 'star_puzzle_rating_v1';
  static const _pixelRatingKey = 'star_pixel_rating_v1';

  int _balance = 0;
  /// Sterne-Show erst im Hub (z. B. Daily-Bonus) — Play zeigt lokal.
  int _pendingHubStars = 0;
  final Set<String> _unlockedColoring = {};
  final Set<String> _unlockedPuzzle = {};
  final Map<String, int> _coloringRatings = {};
  final Map<String, int> _puzzleRatings = {};
  final Map<String, int> _pixelRatings = {};
  StarEconomy? _economy;
  bool _ready = false;

  bool get isReady => _ready;
  int get balance => _balance;

  int get pendingHubStars => _pendingHubStars;

  void queueHubStarDisplay(int amount) {
    if (amount <= 0) return;
    _pendingHubStars += amount;
    notifyListeners();
  }

  int takePendingHubStars() {
    final n = _pendingHubStars;
    _pendingHubStars = 0;
    if (n > 0) notifyListeners();
    return n;
  }
  StarEconomy? get economy => _economy;

  Future<void> load() async {
    _economy = await StarEconomy.load();
    final prefs = await SharedPreferences.getInstance();
    _balance = prefs.getInt(_balanceKey) ?? 0;
    _unlockedColoring
      ..clear()
      ..addAll(prefs.getStringList(_unlockedColoringKey) ?? const []);
    _unlockedPuzzle
      ..clear()
      ..addAll(prefs.getStringList(_unlockedPuzzleKey) ?? const []);
    _coloringRatings
      ..clear()
      ..addAll(_decodeRatings(prefs.getStringList(_coloringRatingKey)));
    _puzzleRatings
      ..clear()
      ..addAll(_decodeRatings(prefs.getStringList(_puzzleRatingKey)));
    _pixelRatings
      ..clear()
      ..addAll(_decodeRatings(prefs.getStringList(_pixelRatingKey)));
    // Alt: einmalig belohnt → als 3★ werten (kein erneutes Auszahlen).
    final legacyRewarded = prefs.getStringList(_puzzleRewardedKey) ?? const [];
    for (final id in legacyRewarded) {
      if (id.isEmpty) continue;
      _puzzleRatings.putIfAbsent(id, () => 3);
    }
    // Advent-Türchen-Freischaltungen in die Wallet übernehmen.
    final advent = AdventService.instance;
    if (!advent.isReady) await advent.load();
    _unlockedColoring.addAll(advent.unlockedColoringIds);
    _unlockedPuzzle.addAll(advent.unlockedPuzzleIds);
    _ready = true;
    notifyListeners();
  }

  Map<String, int> _decodeRatings(List<String>? raw) {
    final out = <String, int>{};
    if (raw == null) return out;
    for (final entry in raw) {
      final i = entry.lastIndexOf(':');
      if (i <= 0) continue;
      final id = entry.substring(0, i);
      final rating = int.tryParse(entry.substring(i + 1));
      if (rating == null) continue;
      out[id] = rating;
    }
    return out;
  }

  List<String> _encodeRatingsMap(Map<String, int> map) => [
        for (final e in map.entries) '${e.key}:${e.value}',
      ]..sort();

  Future<void> _persistBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_balanceKey, _balance);
  }

  Future<void> _persistUnlocks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _unlockedColoringKey,
      _unlockedColoring.toList(growable: false)..sort(),
    );
    await prefs.setStringList(
      _unlockedPuzzleKey,
      _unlockedPuzzle.toList(growable: false)..sort(),
    );
  }

  Future<void> _persistRatings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _coloringRatingKey,
      _encodeRatingsMap(_coloringRatings),
    );
    await prefs.setStringList(
      _puzzleRatingKey,
      _encodeRatingsMap(_puzzleRatings),
    );
    await prefs.setStringList(
      _pixelRatingKey,
      _encodeRatingsMap(_pixelRatings),
    );
    // Legacy-Key aufräumen — Ratings leben in _puzzleRatingKey.
    await prefs.remove(_puzzleRewardedKey);
  }

  static const adventUnlockCost = 25;

  bool _isAdventLockedContent(String id, FavoriteKind kind) {
    final advent = AdventService.instance;
    return kind == FavoriteKind.puzzle
        ? advent.isConfiguredPuzzle(id)
        : advent.isConfiguredColoring(id);
  }

  bool _isSilvesterLockedPuzzle(String id, FavoriteKind kind) {
    if (kind != FavoriteKind.puzzle) return false;
    if (!AdventService.isSilvesterPuzzle(id)) return false;
    return !StickerCollectionStore.silvesterPackRevealedCached;
  }

  bool requiresStars(String id, FavoriteKind kind) {
    final unlocked =
        kind == FavoriteKind.puzzle ? _unlockedPuzzle : _unlockedColoring;
    if (unlocked.contains(id)) return false;
    // Silvester-Puzzle nur über die Box — kein Stern-Kauf.
    if (_isSilvesterLockedPuzzle(id, kind)) return false;
    final eco = _economy;
    if (eco != null && eco.isLocked(id, kind)) return true;
    // Advent-Motive: im Event-Screen gesperrt, bis Türchen / Sterne / Werbung.
    return _isAdventLockedContent(id, kind);
  }

  int? unlockCost(String id, FavoriteKind kind) {
    if (_isSilvesterLockedPuzzle(id, kind)) return null;
    final fromEco = _economy?.costFor(id, kind);
    if (fromEco != null) return fromEco;
    if (_isAdventLockedContent(id, kind)) return adventUnlockCost;
    return null;
  }

  bool isUnlocked(String id, FavoriteKind kind) {
    final unlocked =
        kind == FavoriteKind.puzzle ? _unlockedPuzzle : _unlockedColoring;
    if (unlocked.contains(id)) return true;
    if (_isSilvesterLockedPuzzle(id, kind)) return false;
    final ecoLocked = _economy?.isLocked(id, kind) ?? false;
    if (!ecoLocked && !_isAdventLockedContent(id, kind)) return true;
    return false;
  }

  /// Kostenlos freischalten (z. B. Advent-Geschenk).
  Future<void> grantUnlock(String id, FavoriteKind kind) async {
    if (!_ready) await load();
    final set =
        kind == FavoriteKind.puzzle ? _unlockedPuzzle : _unlockedColoring;
    if (set.contains(id)) return;
    set.add(id);
    await _persistUnlocks();
    notifyListeners();
  }

  Future<bool> unlockWithStars(String id, FavoriteKind kind) async {
    if (!_ready) await load();
    if (!requiresStars(id, kind)) return true;
    final cost = unlockCost(id, kind);
    if (cost == null || _balance < cost) return false;
    _balance -= cost;
    final set =
        kind == FavoriteKind.puzzle ? _unlockedPuzzle : _unlockedColoring;
    set.add(id);
    await _persistBalance();
    await _persistUnlocks();
    notifyListeners();
    return true;
  }

  Future<void> addStars(int amount) async {
    if (amount <= 0) return;
    if (!_ready) await load();
    _balance += amount;
    await _persistBalance();
    notifyListeners();
  }

  Future<bool> spendStars(int amount) async {
    if (amount <= 0) return true;
    if (!_ready) await load();
    if (_balance < amount) return false;
    _balance -= amount;
    await _persistBalance();
    notifyListeners();
    return true;
  }

  int coloringRating(String id) => _coloringRatings[id] ?? 0;

  /// Nach Ausmal-Reset: Bestwert löschen, damit Dot-Art-Sync nicht stale bleibt.
  Future<void> clearColoringRating(String id) async {
    if (id.isEmpty) return;
    if (!_ready) await load();
    if (!_coloringRatings.containsKey(id)) return;
    _coloringRatings.remove(id);
    await _persistRatings();
    notifyListeners();
  }

  /// Speichert nur das Qualitäts-Rating (ohne Währungs-Sterne), z. B. Daily.
  Future<void> recordColoringRating(String id, int rating) async {
    if (rating < 1 || rating > 3) return;
    if (!_ready) await load();
    final prev = _coloringRatings[id] ?? 0;
    if (rating <= prev) return;
    _coloringRatings[id] = rating;
    await _persistRatings();
    notifyListeners();
  }

  /// Vergibt Sterne bei jedem Abschluss (auch Wiederholung). Bestwert wird weiter gespeichert.
  Future<int> awardColoringRating(String id, int rating) async {
    if (rating < 1 || rating > 3) return 0;
    if (!_ready) await load();
    final eco = _economy;
    if (eco == null) return 0;
    final gain = eco.currencyForColoringRating(rating);
    final prev = _coloringRatings[id] ?? 0;
    if (rating > prev) {
      _coloringRatings[id] = rating;
      await _persistRatings();
    }
    if (gain > 0) {
      _balance += gain;
      await _persistBalance();
    }
    notifyListeners();
    return gain;
  }

  /// Puzzle-Abschluss: Easy=1 / Medium=2 / Pro=3 — jedes Mal, auch bei Wiederholung.
  Future<int> awardPuzzleComplete(String id, {required int rating}) async {
    if (rating < 1 || rating > 3) return 0;
    if (!_ready) await load();
    final eco = _economy;
    if (eco == null) return 0;
    final gain = eco.currencyForPuzzleRating(rating);
    final prev = _puzzleRatings[id] ?? 0;
    if (rating > prev) {
      _puzzleRatings[id] = rating;
      await _persistRatings();
    }
    if (gain > 0) {
      _balance += gain;
      await _persistBalance();
    }
    notifyListeners();
    return gain;
  }

  /// Pixelart: gleiche Währung wie Ausmalen (1/2/5) — jedes Mal, auch bei Wiederholung.
  Future<int> awardPixelRating(String id, {required int rating}) async {
    if (rating < 1 || rating > 3) return 0;
    if (!_ready) await load();
    final eco = _economy;
    if (eco == null) return 0;
    final gain = eco.currencyForColoringRating(rating);
    final prev = _pixelRatings[id] ?? 0;
    if (rating > prev) {
      _pixelRatings[id] = rating;
      await _persistRatings();
    }
    if (gain > 0) {
      _balance += gain;
      await _persistBalance();
    }
    notifyListeners();
    return gain;
  }

  int pixelRatingOf(String id) => _pixelRatings[id] ?? 0;

  Future<int> awardRewardedAd() async {
    if (!_ready) await load();
    final gain = _economy?.rewardedAdReward ?? 5;
    _balance += gain;
    await _persistBalance();
    notifyListeners();
    return gain;
  }

  int get stickerCost => _economy?.stickerCost ?? 150;

  /// Temp beim Ausmalen: Besitz 15★, neu 40★.
  int stickerTempCostFor({required bool owned}) => owned
      ? (_economy?.stickerTempOwnedCost ?? 15)
      : (_economy?.stickerTempNewCost ?? 40);

  Set<String> get lockedColoringIds => _economy?.lockedIds(FavoriteKind.coloring) ?? {};
  Set<String> get lockedPuzzleIds => _economy?.lockedIds(FavoriteKind.puzzle) ?? {};
}
