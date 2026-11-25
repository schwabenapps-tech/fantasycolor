import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Advent 1.–25.12. — Claims, Pull-Counts, Season-Gates.
class AdventService extends ChangeNotifier {
  AdventService._();

  static final AdventService instance = AdventService._();

  static const _claimsKey = 'advent_claims_v1';
  static const _unlockedColoringKey = 'advent_unlocked_coloring_v1';
  static const _unlockedPuzzleKey = 'advent_unlocked_puzzle_v1';
  /// Epoch bumpen → Claims/Unlocks einmalig löschen (Inhalt neu befüllen).
  static const _progressEpochKey = 'advent_progress_epoch_v1';
  static const _progressEpoch = 2;

  bool _ready = false;
  Map<int, List<AdventReward>> _claims = {};
  Set<String> _unlockedColoring = {};
  Set<String> _unlockedPuzzle = {};
  Map<int, AdventDoorConfig> _doors = {};

  bool get isReady => _ready;

  /// TEMP: Winter-Hub-UI erzwingen (nur für lokale Tests).
  /// Advent-Türchen starten immer erst ab 1.12. (echtes Datum).
  static const bool debugForceWinterTest = false;

  /// Kalenderdatum für Türchen / Advent-Season (immer echt, kein Fake-25.12.).
  static DateTime _effectiveNow([DateTime? now]) => now ?? DateTime.now();

  /// Exklusiv über Weihnachts-Geschenkbox am 1. Advent (nicht als Türchen).
  static const firstAdventStickerId = 'winter_advent_1';

  /// Nur am 31.12. über Silvester-Box / Daily Gift — nie im Adventskalender.
  /// Bis die Silvester-Box geöffnet wurde: nicht im Album sichtbar.
  static const silvesterStickerIds = <String>{
    'winter_silvester_sticker',
    'winter_happy_new_year',
  };

  /// Silvester-Puzzles — erst nach Öffnen der Silvester-Box sichtbar/spielbar.
  /// 1) mehrere Feen / Feuerwerk  2) zwei Feen mit Raketen
  static const silvesterPuzzleIds = <String>{
    'feen_bestaunen_das_feuerwerk_im_schnee',
    'silvester_zwei_feen_mit_feuerwerk',
  };

  static bool isSilvesterSticker(String id) => silvesterStickerIds.contains(id);

  static bool isSilvesterPuzzle(String id) => silvesterPuzzleIds.contains(id);

  /// 1. Adventssonntag (vier Sonntage vor Weihnachten, lokal).
  static DateTime firstAdventDate(int year) {
    final christmas = DateTime(year, 12, 25);
    final daysAfterSunday = christmas.weekday % DateTime.daysPerWeek;
    final fourthAdvent = christmas.subtract(Duration(days: daysAfterSunday));
    return fourthAdvent.subtract(const Duration(days: 21));
  }

  /// 1.12. 00:00 – 25.12. 23:59 (lokales Datum).
  static bool isAdventSeason([DateTime? now]) {
    final n = _effectiveNow(now);
    return n.month == 12 && n.day >= 1 && n.day <= 25;
  }

  /// Winter-Hub-UI: ab Mitte November Vorschau, Dez, bis 6.1.
  static bool isWinterHubUi([DateTime? now]) {
    if (debugForceWinterTest) return true;
    final n = now ?? DateTime.now();
    if (n.month == 12) return true;
    if (n.month == 1 && n.day <= 6) return true;
    // Vorschau / Early-Access-Hub vor dem 1.12.
    if (n.month == 11 && n.day >= 15) return true;
    return false;
  }

  /// Weihnachts-Geschenkbox: ab 1. Advent bis einschließlich 25.12.
  static bool usesChristmasGiftBox([DateTime? now]) {
    final n = _effectiveNow(now);
    final start = firstAdventDate(n.year);
    final startDay = DateTime(start.year, start.month, start.day);
    final end = DateTime(n.year, 12, 25);
    final day = DateTime(n.year, n.month, n.day);
    return !day.isBefore(startDay) && !day.isAfter(end);
  }

  static bool isFirstAdventDay([DateTime? now]) {
    final n = _effectiveNow(now);
    final a = firstAdventDate(n.year);
    return n.year == a.year && n.month == a.month && n.day == a.day;
  }

  static bool isNewYearsEve([DateTime? now]) {
    final n = _effectiveNow(now);
    return n.month == 12 && n.day == 31;
  }

  /// Klassische Daily- + Completion-Sticker-Belohnungen.
  static bool classicRewardsEnabled([DateTime? now]) => !isAdventSeason(now);

  /// Adventskalender darf noch geöffnet / nachgeholt werden.
  static bool canOpenDoors([DateTime? now]) => isAdventSeason(now);

  /// Portal in Winter-UI (Öffnen der Türchen erst ab 1.12.).
  bool get showAdventPortal => isWinterHubUi();

  int get todayDoorDay {
    final n = _effectiveNow();
    if (n.month != 12) return 0;
    return n.day.clamp(1, 25);
  }

  /// Noch nicht geöffnete Türchen, die heute (oder nachholbar) offen sind.
  /// Gesperrte Zukunfts-Türchen zählen nicht.
  int get openableUnopenedCount {
    var n = 0;
    for (var d = 1; d <= 25; d++) {
      if (canOpen(d)) n++;
    }
    return n;
  }

  /// Bereits geöffnete Türchen (1–25).
  int get openedCount => _claims.length;

  Set<String> get unlockedColoringIds => Set.unmodifiable(_unlockedColoring);
  Set<String> get unlockedPuzzleIds => Set.unmodifiable(_unlockedPuzzle);

  /// Alle in advent_2026.json gesetzten Ausmal-/Puzzle-IDs (für Event-Screen).
  Set<String> get configuredColoringIds => {
        for (final d in _doors.values)
          if (d.coloringId != null && d.coloringId!.isNotEmpty) d.coloringId!,
      };

  Set<String> get configuredPuzzleIds => {
        for (final d in _doors.values)
          if (d.puzzleId != null && d.puzzleId!.isNotEmpty) d.puzzleId!,
      };

  bool isConfiguredColoring(String id) => configuredColoringIds.contains(id);
  bool isConfiguredPuzzle(String id) => configuredPuzzleIds.contains(id);

  Future<void> load() async {
    try {
      await _loadConfig();
      final prefs = await SharedPreferences.getInstance();
      final epoch = prefs.getInt(_progressEpochKey) ?? 0;
      if (epoch != _progressEpoch) {
        await resetProgress(prefs: prefs);
        await prefs.setInt(_progressEpochKey, _progressEpoch);
      } else {
        _claims = _decodeClaims(prefs.getString(_claimsKey));
        _unlockedColoring = {
          ...(prefs.getStringList(_unlockedColoringKey) ?? const <String>[]),
        };
        _unlockedPuzzle = {
          ...(prefs.getStringList(_unlockedPuzzleKey) ?? const <String>[]),
        };
        // Claims → freigeschaltete IDs (auch ältere Saves ohne Unlock-Liste).
        for (final rewards in _claims.values) {
          for (final r in rewards) {
            if (r.type == AdventRewardType.coloring && r.id.isNotEmpty) {
              _unlockedColoring.add(r.id);
            }
            if (r.type == AdventRewardType.puzzle && r.id.isNotEmpty) {
              _unlockedPuzzle.add(r.id);
            }
          }
        }
      }
    } catch (e, st) {
      debugPrint('AdventService.load failed: $e\n$st');
    }
    _ready = true;
    notifyListeners();
  }

  /// Alle Türchen-Claims und Advent-Unlocks löschen (Sticker-Album unberührt).
  Future<void> resetProgress({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    _claims = {};
    _unlockedColoring = {};
    _unlockedPuzzle = {};
    await p.remove(_claimsKey);
    await p.remove(_unlockedColoringKey);
    await p.remove(_unlockedPuzzleKey);
    notifyListeners();
  }

  Future<void> _loadConfig() async {
    try {
      final raw = await rootBundle.loadString('assets/advent_2026.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final doors = <int, AdventDoorConfig>{};
      final list = json['doors'];
      if (list is List) {
        for (final item in list) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final day = (map['day'] as num?)?.toInt() ?? 0;
          if (day < 1 || day > 25) continue;
          doors[day] = AdventDoorConfig(
            day: day,
            pulls: (map['pulls'] as num?)?.toInt() ?? _defaultPulls(day),
            special: map['special'] == true || day >= 24,
            bonusStars: (map['bonusStars'] as num?)?.toInt() ??
                (day == 25 ? 20 : 0),
            stickerId: map['stickerId']?.toString(),
            coloringId: map['coloringId']?.toString(),
            puzzleId: map['puzzleId']?.toString(),
          );
        }
      }
      // Defaults für fehlende Tage.
      for (var d = 1; d <= 25; d++) {
        doors.putIfAbsent(
          d,
          () => AdventDoorConfig(
            day: d,
            pulls: _defaultPulls(d),
            special: d >= 24,
            bonusStars: d == 25 ? 20 : 0,
          ),
        );
      }
      _doors = doors;
    } catch (e, st) {
      debugPrint('AdventService config failed: $e\n$st');
      _doors = {
        for (var d = 1; d <= 25; d++)
          d: AdventDoorConfig(
            day: d,
            pulls: _defaultPulls(d),
            special: d >= 24,
            bonusStars: d == 25 ? 20 : 0,
          ),
      };
    }
  }

  static int _defaultPulls(int day) {
    if (day == 25) return 3;
    if (day == 24) return 2;
    return 1;
  }

  /// Belohnungs-Typen aus Türchen-Config (gesetzte IDs); Fallback-Zyklus.
  static List<AdventRewardType> rewardTypesForDay(int day) {
    final cfg = instance._doors[day];
    if (cfg != null) {
      final fromConfig = <AdventRewardType>[
        if (cfg.stickerId != null && cfg.stickerId!.isNotEmpty)
          AdventRewardType.sticker,
        if (cfg.coloringId != null && cfg.coloringId!.isNotEmpty)
          AdventRewardType.coloring,
        if (cfg.puzzleId != null && cfg.puzzleId!.isNotEmpty)
          AdventRewardType.puzzle,
      ];
      if (fromConfig.isNotEmpty) return fromConfig;
    }
    if (day == 25) {
      return const [
        AdventRewardType.sticker,
        AdventRewardType.coloring,
        AdventRewardType.puzzle,
      ];
    }
    if (day == 24) {
      return const [
        AdventRewardType.sticker,
        AdventRewardType.coloring,
      ];
    }
    const cycle = [
      AdventRewardType.sticker,
      AdventRewardType.coloring,
      AdventRewardType.puzzle,
    ];
    return [cycle[(day - 1) % 3]];
  }

  int bonusStarsFor(int day) => doorConfig(day).bonusStars;

  AdventDoorConfig doorConfig(int day) =>
      _doors[day] ?? AdventDoorConfig(day: day, pulls: 1);

  bool isOpened(int day) => _claims.containsKey(day);

  List<AdventReward> rewardsFor(int day) =>
      List.unmodifiable(_claims[day] ?? const []);

  /// Türchen freigeschaltet (heute oder Vergangenheit), noch nicht geöffnet.
  bool canOpen(int day, {DateTime? now}) {
    if (!canOpenDoors(now)) return false;
    if (day < 1 || day > 25) return false;
    if (isOpened(day)) return false;
    final n = _effectiveNow(now);
    if (n.month != 12) return false;
    return day <= n.day;
  }

  bool isLockedFuture(int day, {DateTime? now}) {
    final n = _effectiveNow(now);
    if (n.month != 12) return day >= 1;
    return day > n.day;
  }

  Future<void> saveClaim(int day, List<AdventReward> rewards) async {
    _claims[day] = List.of(rewards);
    for (final r in rewards) {
      if (r.type == AdventRewardType.coloring && r.id.isNotEmpty) {
        _unlockedColoring.add(r.id);
      }
      if (r.type == AdventRewardType.puzzle && r.id.isNotEmpty) {
        _unlockedPuzzle.add(r.id);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claimsKey, _encodeClaims(_claims));
    await prefs.setStringList(
      _unlockedColoringKey,
      _unlockedColoring.toList()..sort(),
    );
    await prefs.setStringList(
      _unlockedPuzzleKey,
      _unlockedPuzzle.toList()..sort(),
    );
    notifyListeners();
  }

  Map<int, List<AdventReward>> _decodeClaims(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final out = <int, List<AdventReward>>{};
      for (final e in map.entries) {
        final day = int.tryParse(e.key) ?? 0;
        if (day < 1) continue;
        final list = e.value;
        if (list is! List) continue;
        out[day] = [
          for (final item in list)
            if (item is Map)
              AdventReward.fromJson(Map<String, dynamic>.from(item)),
        ];
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  String _encodeClaims(Map<int, List<AdventReward>> claims) {
    return jsonEncode({
      for (final e in claims.entries)
        '${e.key}': [for (final r in e.value) r.toJson()],
    });
  }
}

enum AdventRewardType { sticker, coloring, puzzle }

class AdventReward {
  const AdventReward({required this.type, required this.id});

  final AdventRewardType type;
  final String id;

  factory AdventReward.fromJson(Map<String, dynamic> json) {
    final typeRaw = json['type']?.toString() ?? 'sticker';
    final type = switch (typeRaw) {
      'coloring' => AdventRewardType.coloring,
      'puzzle' => AdventRewardType.puzzle,
      _ => AdventRewardType.sticker,
    };
    return AdventReward(type: type, id: json['id']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {
        'type': switch (type) {
          AdventRewardType.coloring => 'coloring',
          AdventRewardType.puzzle => 'puzzle',
          AdventRewardType.sticker => 'sticker',
        },
        'id': id,
      };
}

class AdventDoorConfig {
  const AdventDoorConfig({
    required this.day,
    required this.pulls,
    this.special = false,
    this.bonusStars = 0,
    this.stickerId,
    this.coloringId,
    this.puzzleId,
  });

  final int day;
  final int pulls;
  final bool special;
  final int bonusStars;
  /// Explizite Advent-Assets — erst setzen, wenn die Dateien da sind.
  final String? stickerId;
  final String? coloringId;
  final String? puzzleId;

  AdventDoorConfig copyWith({
    int? pulls,
    bool? special,
    int? bonusStars,
    String? stickerId,
    String? coloringId,
    String? puzzleId,
  }) {
    return AdventDoorConfig(
      day: day,
      pulls: pulls ?? this.pulls,
      special: special ?? this.special,
      bonusStars: bonusStars ?? this.bonusStars,
      stickerId: stickerId ?? this.stickerId,
      coloringId: coloringId ?? this.coloringId,
      puzzleId: puzzleId ?? this.puzzleId,
    );
  }
}
