import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/event_tags.dart';

/// Advent 1.–25.12. — Claims, Pull-Counts, Season-Gates.
class AdventService extends ChangeNotifier {
  AdventService._();

  static final AdventService instance = AdventService._();

  static const _claimsKey = 'advent_claims_v1';
  static const _unlockedColoringKey = 'advent_unlocked_coloring_v1';
  static const _unlockedPuzzleKey = 'advent_unlocked_puzzle_v1';

  bool _ready = false;
  Map<int, List<AdventReward>> _claims = {};
  Set<String> _unlockedColoring = {};
  Set<String> _unlockedPuzzle = {};
  Map<int, AdventDoorConfig> _doors = {};

  bool get isReady => _ready;

  /// TEMP: Winter-Hub-UI erzwingen (Schnee/Backdrop) — ohne Türchen freizuschalten.
  /// Türchen folgen immer dem echten Kalenderdatum.
  /// Vor Store-Release auf `false` setzen.
  static const bool debugForceWinterTest = true;

  /// Kalenderdatum für Türchen / Advent-Season (immer echt, kein Fake-25.12.).
  static DateTime _effectiveNow([DateTime? now]) => now ?? DateTime.now();

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

  Set<String> get unlockedColoringIds => Set.unmodifiable(_unlockedColoring);
  Set<String> get unlockedPuzzleIds => Set.unmodifiable(_unlockedPuzzle);

  Future<void> load() async {
    try {
      // Winter-Event aus event_tags.json nach Asset-Update neu lesen.
      EventTags.clearCache();
      await _loadConfig();
      final prefs = await SharedPreferences.getInstance();
      _claims = _decodeClaims(prefs.getString(_claimsKey));
      _unlockedColoring = {
        ...(prefs.getStringList(_unlockedColoringKey) ?? const <String>[]),
      };
      _unlockedPuzzle = {
        ...(prefs.getStringList(_unlockedPuzzleKey) ?? const <String>[]),
      };
    } catch (e, st) {
      debugPrint('AdventService.load failed: $e\n$st');
    }
    _ready = true;
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
            pulls: (map['pulls'] as num?)?.toInt() ?? 1,
            special: map['special'] == true,
            coloringId: map['coloringId']?.toString(),
            puzzleId: map['puzzleId']?.toString(),
          );
        }
      }
      final content = json['content_rewards'];
      if (content is Map) {
        for (final entry in content.entries) {
          final day = int.tryParse(entry.key.toString()) ?? 0;
          if (day < 1 || day > 25) continue;
          final rawReward = entry.value;
          if (rawReward is! Map) continue;
          final map = Map<String, dynamic>.from(rawReward);
          final existing = doors[day] ??
              AdventDoorConfig(day: day, pulls: day == 25 ? 3 : 1);
          doors[day] = existing.copyWith(
            coloringId: map['coloringId']?.toString() ?? existing.coloringId,
            puzzleId: map['puzzleId']?.toString() ?? existing.puzzleId,
            special: true,
          );
        }
      }
      // Defaults für fehlende Tage.
      for (var d = 1; d <= 25; d++) {
        doors.putIfAbsent(
          d,
          () => AdventDoorConfig(
            day: d,
            pulls: d == 25 ? 3 : (d == 24 ? 2 : 1),
            special: d == 24 || d == 25 || {6, 13, 20}.contains(d),
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
            pulls: d == 25 ? 3 : (d == 24 || {6, 13, 20}.contains(d) ? 2 : 1),
            special: d == 24 || d == 25 || {6, 13, 20}.contains(d),
          ),
      };
    }
  }

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
    this.coloringId,
    this.puzzleId,
  });

  final int day;
  final int pulls;
  final bool special;
  final String? coloringId;
  final String? puzzleId;

  AdventDoorConfig copyWith({
    int? pulls,
    bool? special,
    String? coloringId,
    String? puzzleId,
  }) {
    return AdventDoorConfig(
      day: day,
      pulls: pulls ?? this.pulls,
      special: special ?? this.special,
      coloringId: coloringId ?? this.coloringId,
      puzzleId: puzzleId ?? this.puzzleId,
    );
  }
}
