import 'dart:convert';

import 'package:flutter/services.dart';

import '../providers/favorites_store.dart';

/// Belohnungen, Preise und gesperrte Motive (assets/star_economy.json).
class StarEconomy {
  StarEconomy._({
    required this.coloringStarRewards,
    required this.coloringThresholds,
    required this.puzzleStarRewards,
    required this.rewardedAdReward,
    required this.stickerCost,
    required this.stickerTempOwnedCost,
    required this.stickerTempNewCost,
    required Map<String, int> lockedColoring,
    required Map<String, int> lockedPuzzle,
  })  : _lockedColoring = Map<String, int>.unmodifiable(lockedColoring),
        _lockedPuzzle = Map<String, int>.unmodifiable(lockedPuzzle);

  final Map<int, int> coloringStarRewards;
  final Map<int, double> coloringThresholds;
  /// Puzzle: Easy=1 / Medium=2 / Pro=3 Sterne (Währung + Flug-Sterne).
  final Map<int, int> puzzleStarRewards;
  final int rewardedAdReward;
  /// Klassik-Album: dauerhafter Besitz.
  final int stickerCost;
  /// Ausmalen temp: bereits im Besitz.
  final int stickerTempOwnedCost;
  /// Ausmalen temp: noch nicht im Besitz.
  final int stickerTempNewCost;
  final Map<String, int> _lockedColoring;
  final Map<String, int> _lockedPuzzle;

  static StarEconomy? _cache;

  static Future<StarEconomy> load({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/star_economy.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final rewards = json['rewards'] as Map<String, dynamic>? ?? const {};
    final starMap = rewards['coloring_stars'] as Map<String, dynamic>? ??
        const {'1': 1, '2': 2, '3': 5};
    final puzzleMap = rewards['puzzle_stars'] as Map<String, dynamic>? ??
        const {'1': 1, '2': 2, '3': 3};
    final thresh = rewards['coloring_thresholds'] as Map<String, dynamic>? ??
        const {'1': 0.50, '2': 0.80, '3': 1.0};
    _cache = StarEconomy._(
      coloringStarRewards: {
        for (final e in starMap.entries) int.parse(e.key): (e.value as num).toInt(),
      },
      coloringThresholds: {
        for (final e in thresh.entries)
          int.parse(e.key): (e.value as num).toDouble(),
      },
      puzzleStarRewards: {
        for (final e in puzzleMap.entries)
          int.parse(e.key): (e.value as num).toInt(),
      },
      rewardedAdReward: (rewards['rewarded_ad'] as num?)?.toInt() ?? 5,
      stickerCost: (rewards['sticker_cost'] as num?)?.toInt() ?? 150,
      stickerTempOwnedCost:
          (rewards['sticker_temp_owned_cost'] as num?)?.toInt() ?? 15,
      stickerTempNewCost: (rewards['sticker_temp_cost'] as num?)?.toInt() ?? 40,
      lockedColoring: _idCostMap(json['locked_coloring']),
      lockedPuzzle: _idCostMap(json['locked_puzzle']),
    );
    return _cache!;
  }

  static Map<String, int> _idCostMap(Object? raw) {
    if (raw is! List) return {};
    final out = <String, int>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final id = item['id']?.toString();
      final cost = item['cost'];
      if (id == null || id.isEmpty || cost is! num) continue;
      out[id] = cost.toInt();
    }
    return out;
  }

  bool isLocked(String id, FavoriteKind kind) {
    final map = kind == FavoriteKind.puzzle ? _lockedPuzzle : _lockedColoring;
    return map.containsKey(id);
  }

  int? costFor(String id, FavoriteKind kind) {
    final map = kind == FavoriteKind.puzzle ? _lockedPuzzle : _lockedColoring;
    return map[id];
  }

  List<String> freeIds(FavoriteKind kind) {
    final locked =
        kind == FavoriteKind.puzzle ? _lockedPuzzle : _lockedColoring;
    // Caller filtered against full catalog; expose locked set for exclusion.
    return locked.keys.toList(growable: false);
  }

  Set<String> lockedIds(FavoriteKind kind) => Set.unmodifiable(
        kind == FavoriteKind.puzzle ? _lockedPuzzle.keys : _lockedColoring.keys,
      );

  /// 0 = kein Stern, 1–3 nach Coverage.
  int ratingForCoverage(double coverage) {
    final t3 = coloringThresholds[3] ?? 1.0;
    final t2 = coloringThresholds[2] ?? 0.80;
    final t1 = coloringThresholds[1] ?? 0.50;
    if (coverage >= t3) return 3;
    if (coverage >= t2) return 2;
    if (coverage >= t1) return 1;
    return 0;
  }

  int currencyForColoringRating(int rating) =>
      coloringStarRewards[rating] ?? 0;

  int currencyForPuzzleRating(int rating) =>
      puzzleStarRewards[rating] ?? 0;
}
