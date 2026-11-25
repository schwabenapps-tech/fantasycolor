import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/coloring_pages_loader.dart';
import '../data/event_tags.dart';
import '../data/puzzle_images_loader.dart';
import '../data/star_economy.dart';
import '../models/puzzle_settings.dart';
import '../providers/favorites_store.dart';
import '../providers/pixel_progress_store.dart';
import '../providers/pixel_ready_store.dart';
import '../providers/star_wallet_store.dart';
import '../widgets/daily_quest_overlay.dart';
import 'advent_service.dart';

enum DailyQuestTaskKind {
  coloring,
  puzzle,
  placeSticker,
  pixel,
  recolor,
  unlockChoice,
  watchAd,
  coloringThreeStar,
  pixelThreeStar,
  eventFinish,
  adventDoor,
}

/// Puzzle-Anforderung für die Aufgabe.
enum DailyQuestPuzzleRequirement {
  /// Easy erlaubt (beliebige Schwierigkeit).
  any,

  /// Mindestens Medium oder Schwer (Pro).
  mediumOrHard,

  /// Nur Schwer / Expert.
  hardOnly,
}

class DailyQuestTask {
  const DailyQuestTask({
    required this.slotId,
    required this.kind,
    required this.pageId,
    this.puzzleRequirement = DailyQuestPuzzleRequirement.any,
  });

  /// Stabiler Slot (color / puzzle / sticker / pixel / recolor / unlock).
  final String slotId;
  final DailyQuestTaskKind kind;
  final String pageId;
  final DailyQuestPuzzleRequirement puzzleRequirement;

  static const anyPageId = '_any_';

  bool get isColoring => kind == DailyQuestTaskKind.coloring;
  bool get isPuzzle => kind == DailyQuestTaskKind.puzzle;
  bool get isPlaceSticker => kind == DailyQuestTaskKind.placeSticker;
  bool get isPixel => kind == DailyQuestTaskKind.pixel;
  bool get isRecolor => kind == DailyQuestTaskKind.recolor;
  bool get isUnlockChoice => kind == DailyQuestTaskKind.unlockChoice;
  bool get isWatchAd => kind == DailyQuestTaskKind.watchAd;
  bool get isColoringThreeStar => kind == DailyQuestTaskKind.coloringThreeStar;
  bool get isPixelThreeStar => kind == DailyQuestTaskKind.pixelThreeStar;
  bool get isEventFinish => kind == DailyQuestTaskKind.eventFinish;
  bool get isAdventDoor => kind == DailyQuestTaskKind.adventDoor;
}

/// Tagesquest: immer bis zu 3 abwechslungsreiche Aufgaben.
class DailyQuestService extends ChangeNotifier {
  DailyQuestService();

  static const _dayKey = 'daily_quest_day_v1';
  static const _tasksKey = 'daily_quest_tasks_v4';
  static const _doneKey = 'daily_quest_done_v4';
  static const _completedDayKey = 'daily_quest_completed_day_v1';
  static const _starsAwardedKey = 'daily_quest_stars_awarded_day_v1';
  static const _stickerTierKey = 'daily_quest_sticker_tier_day_v1';
  static const _pendingHubKey = 'daily_quest_pending_hub_v1';

  static const completeStarReward = 10;

  bool _ready = false;
  String? _day;
  List<DailyQuestTask> _tasks = const [];
  final Set<String> _done = {};
  String? _completedDay;
  String? _starsAwardedDay;
  /// Tag + wie viele Daily-Sticker schon vergeben (0–2).
  String? _stickerTierDay;
  int _stickersClaimed = 0;

  /// Hub: Daily-Liste öffnen + Belohnungs-Sequenz.
  bool _pendingHubOpenList = false;
  int _pendingHubStickers = 0;
  int _pendingHubStars = 0;

  bool get isReady => _ready;
  List<DailyQuestTask> get tasks => List.unmodifiable(_tasks);
  bool get isCompletedToday => _completedDay == _todayKey();

  String _slotDoneKey(DailyQuestTask t) {
    final slot = t.slotId;
    if (slot.isEmpty) {
      return '${t.isPuzzle ? 'p' : 'c'}:${t.pageId}';
    }
    return slot;
  }

  bool isTaskDone(DailyQuestTask task) {
    try {
      return _done.contains(_slotDoneKey(task));
    } catch (_) {
      return false;
    }
  }

  bool _tasksValid(List<DailyQuestTask> tasks) {
    if (tasks.isEmpty) return false;
    for (final t in tasks) {
      try {
        if (t.slotId.isEmpty || t.pageId.isEmpty) return false;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  String _todayKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  /// Stabiler Tages-Index für „alle N Tage“-Quests (yyyy-MM-dd).
  static int _dayOrdinal(String seed) {
    final parsed = DateTime.tryParse(seed);
    final day = parsed ?? DateTime.now();
    return DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(2020, 1, 1))
        .inDays;
  }

  Future<void> load({
    List<String> freeColoringIds = const [],
    List<String> freePuzzleIds = const [],
    List<String> pixelReadyIds = const [],
    List<String> pixelInProgressIds = const [],
    List<String> finishedColoringIds = const [],
    List<String> eventColoringIds = const [],
    bool hasStarLockedContent = false,
    bool adventDoorAvailable = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _completedDay = prefs.getString(_completedDayKey);
    _starsAwardedDay = prefs.getString(_starsAwardedKey);
    _loadStickerTier(prefs.getString(_stickerTierKey));
    _loadPendingHub(prefs.getString(_pendingHubKey));
    final today = _todayKey();
    final completedToday = _completedDay == today;
    _day = prefs.getString(_dayKey);
    _done
      ..clear()
      ..addAll(prefs.getStringList(_doneKey) ?? const []);

    if (_day != today) {
      // Neuer Kalendertag → frische max. 3 Aufgaben.
      _day = today;
      _tasks = _generate(
        freeColoringIds: freeColoringIds,
        freePuzzleIds: freePuzzleIds,
        pixelReadyIds: pixelReadyIds,
        pixelInProgressIds: pixelInProgressIds,
        finishedColoringIds: finishedColoringIds,
        eventColoringIds: eventColoringIds,
        hasStarLockedContent: hasStarLockedContent,
        adventDoorAvailable: adventDoorAvailable,
        seed: today,
      );
      _done.clear();
      await prefs.setString(_dayKey, today);
      await prefs.setStringList(_tasksKey, _encodeTasks(_tasks));
      await prefs.setStringList(_doneKey, const []);
    } else {
      final raw = prefs.getStringList(_tasksKey) ?? const [];
      _tasks = _decodeTasks(raw);
      if (_tasks.length > 3) {
        _tasks = _tasks.take(3).toList(growable: false);
        await prefs.setStringList(_tasksKey, _encodeTasks(_tasks));
      }
      // Schon fertig heute → niemals neu würfeln (auch nach App-Neustart).
      if (completedToday) {
        // Done-Keys beibehalten; fehlende Tasks nicht ersetzen.
      } else if (!_tasksValid(_tasks)) {
        // Nur reparieren, wenn der Tag noch nicht abgeschlossen ist.
        _tasks = _generate(
          freeColoringIds: freeColoringIds,
          freePuzzleIds: freePuzzleIds,
          pixelReadyIds: pixelReadyIds,
          pixelInProgressIds: pixelInProgressIds,
          finishedColoringIds: finishedColoringIds,
          eventColoringIds: eventColoringIds,
          hasStarLockedContent: hasStarLockedContent,
          adventDoorAvailable: adventDoorAvailable,
          seed: today,
        );
        _done.clear();
        await prefs.setStringList(_tasksKey, _encodeTasks(_tasks));
        await prefs.setStringList(_doneKey, const []);
      }
    }
    _ready = true;
    notifyListeners();
  }

  List<String> _encodeTasks(List<DailyQuestTask> tasks) => [
        for (final t in tasks)
          [
            t.slotId,
            switch (t.kind) {
              DailyQuestTaskKind.puzzle => 'p',
              DailyQuestTaskKind.placeSticker => 's',
              DailyQuestTaskKind.pixel => 'x',
              DailyQuestTaskKind.recolor => 'r',
              DailyQuestTaskKind.unlockChoice => 'u',
              DailyQuestTaskKind.watchAd => 'a',
              DailyQuestTaskKind.coloringThreeStar => 'c3',
              DailyQuestTaskKind.pixelThreeStar => 'x3',
              DailyQuestTaskKind.eventFinish => 'e',
              DailyQuestTaskKind.adventDoor => 'd',
              DailyQuestTaskKind.coloring => 'c',
            },
            t.pageId,
            switch (t.puzzleRequirement) {
              DailyQuestPuzzleRequirement.hardOnly => 'h',
              DailyQuestPuzzleRequirement.mediumOrHard => 'mh',
              DailyQuestPuzzleRequirement.any => 'any',
            },
          ].join('|'),
      ];

  List<DailyQuestTask> _decodeTasks(List<String> raw) {
    final out = <DailyQuestTask>[];
    for (final e in raw) {
      final parts = e.split('|');
      if (parts.length < 4) continue;
      final kind = switch (parts[1]) {
        'p' => DailyQuestTaskKind.puzzle,
        's' => DailyQuestTaskKind.placeSticker,
        'x' => DailyQuestTaskKind.pixel,
        'r' => DailyQuestTaskKind.recolor,
        'u' => DailyQuestTaskKind.unlockChoice,
        'a' => DailyQuestTaskKind.watchAd,
        'c3' => DailyQuestTaskKind.coloringThreeStar,
        'x3' => DailyQuestTaskKind.pixelThreeStar,
        'e' => DailyQuestTaskKind.eventFinish,
        'd' => DailyQuestTaskKind.adventDoor,
        _ => DailyQuestTaskKind.coloring,
      };
      final req = switch (parts[3]) {
        'h' => DailyQuestPuzzleRequirement.hardOnly,
        'mh' => DailyQuestPuzzleRequirement.mediumOrHard,
        _ => DailyQuestPuzzleRequirement.any,
      };
      out.add(
        DailyQuestTask(
          slotId: parts[0],
          kind: kind,
          pageId: parts[2],
          puzzleRequirement: req,
        ),
      );
    }
    return out;
  }

  /// 1–3 abwechslungsreiche Aufgaben; Typen max. 1× (kein Doppel-Puzzle).
  /// Fertige Colorings/Pixel/Unlocks bleiben wiederverwendbar.
  List<DailyQuestTask> _generate({
    required List<String> freeColoringIds,
    required List<String> freePuzzleIds,
    required String seed,
    List<String> pixelReadyIds = const [],
    List<String> pixelInProgressIds = const [],
    List<String> finishedColoringIds = const [],
    List<String> eventColoringIds = const [],
    bool hasStarLockedContent = false,
    bool adventDoorAvailable = false,
  }) {
    final rng = Random(seed.hashCode);
    final coloring = [...freeColoringIds]..shuffle(rng);
    final puzzles = [...freePuzzleIds]..shuffle(rng);
    // Offene Dot Arts zuerst — Daily soll angefangene Bilder priorisieren.
    final inProgress = [...pixelInProgressIds]..shuffle(rng);
    final inProgressSet = inProgress.toSet();
    final pixelRest = [
      for (final id in pixelReadyIds)
        if (!inProgressSet.contains(id)) id,
    ]..shuffle(rng);
    final pixelReady = [...inProgress, ...pixelRest];
    final hasOpenPixel = inProgress.isNotEmpty;
    final finished = [
      ...{
        ...finishedColoringIds,
        ...pixelReadyIds,
      },
    ]..shuffle(rng);
    final events = [...eventColoringIds]..shuffle(rng);

    // Pro Tag 1, 2 oder 3 Aufgaben — gleichmäßig, kann hintereinander gleich sein.
    final targetCount = 1 + rng.nextInt(3);

    var colorIdx = 0;
    var puzzleIdx = 0;
    var pixelIdx = 0;
    var recolorIdx = 0;
    var eventIdx = 0;
    final out = <DailyQuestTask>[];

    DailyQuestTask? buildKind(DailyQuestTaskKind kind) {
      switch (kind) {
        case DailyQuestTaskKind.coloring:
          if (colorIdx >= coloring.length) return null;
          return DailyQuestTask(
            slotId: 'color_${out.length}',
            kind: DailyQuestTaskKind.coloring,
            pageId: coloring[colorIdx++],
          );
        case DailyQuestTaskKind.puzzle:
          if (puzzleIdx >= puzzles.length) return null;
          // Abwechselnd Easy / Medium / Schwer.
          final req = switch (rng.nextInt(3)) {
            0 => DailyQuestPuzzleRequirement.any,
            1 => DailyQuestPuzzleRequirement.mediumOrHard,
            _ => DailyQuestPuzzleRequirement.hardOnly,
          };
          final slot = switch (req) {
            DailyQuestPuzzleRequirement.any => 'puzzle_any_${out.length}',
            DailyQuestPuzzleRequirement.mediumOrHard =>
              'puzzle_mh_${out.length}',
            DailyQuestPuzzleRequirement.hardOnly => 'puzzle_h_${out.length}',
          };
          return DailyQuestTask(
            slotId: slot,
            kind: DailyQuestTaskKind.puzzle,
            pageId: puzzles[puzzleIdx++],
            puzzleRequirement: req,
          );
        case DailyQuestTaskKind.placeSticker:
          if (coloring.isEmpty) return null;
          final id = colorIdx < coloring.length
              ? coloring[colorIdx++]
              : coloring[rng.nextInt(coloring.length)];
          return DailyQuestTask(
            slotId: 'sticker_${out.length}',
            kind: DailyQuestTaskKind.placeSticker,
            pageId: id,
          );
        case DailyQuestTaskKind.pixel:
          if (pixelIdx >= pixelReady.length) return null;
          return DailyQuestTask(
            slotId: 'pixel_${out.length}',
            kind: DailyQuestTaskKind.pixel,
            pageId: pixelReady[pixelIdx++],
          );
        case DailyQuestTaskKind.recolor:
          if (recolorIdx >= finished.length) return null;
          return DailyQuestTask(
            slotId: 'recolor_${out.length}',
            kind: DailyQuestTaskKind.recolor,
            pageId: finished[recolorIdx++],
          );
        case DailyQuestTaskKind.unlockChoice:
          if (!hasStarLockedContent) return null;
          return DailyQuestTask(
            slotId: 'unlock_${out.length}',
            kind: DailyQuestTaskKind.unlockChoice,
            pageId: DailyQuestTask.anyPageId,
          );
        case DailyQuestTaskKind.watchAd:
          return DailyQuestTask(
            slotId: 'ad_${out.length}',
            kind: DailyQuestTaskKind.watchAd,
            pageId: DailyQuestTask.anyPageId,
          );
        case DailyQuestTaskKind.coloringThreeStar:
          if (colorIdx >= coloring.length) return null;
          return DailyQuestTask(
            slotId: 'color3_${out.length}',
            kind: DailyQuestTaskKind.coloringThreeStar,
            pageId: coloring[colorIdx++],
          );
        case DailyQuestTaskKind.pixelThreeStar:
          if (pixelIdx >= pixelReady.length) return null;
          return DailyQuestTask(
            slotId: 'pixel3_${out.length}',
            kind: DailyQuestTaskKind.pixelThreeStar,
            pageId: pixelReady[pixelIdx++],
          );
        case DailyQuestTaskKind.eventFinish:
          if (eventIdx >= events.length) return null;
          return DailyQuestTask(
            slotId: 'event_${out.length}',
            kind: DailyQuestTaskKind.eventFinish,
            pageId: events[eventIdx++],
          );
        case DailyQuestTaskKind.adventDoor:
          if (!adventDoorAvailable) return null;
          return DailyQuestTask(
            slotId: 'advent_${out.length}',
            kind: DailyQuestTaskKind.adventDoor,
            pageId: DailyQuestTask.anyPageId,
          );
      }
    }

    // Schwere/leichte Spezial-Tasks nur alle 2–3 Tage (versetzt, nicht am selben Tag).
    final dayOrd = _dayOrdinal(seed);
    final allowWatchAd = dayOrd % 3 == 0;
    final allowPixelQuest = dayOrd % 3 == 1;

    // Wiederkehrende Daily-Ideen — je Typ höchstens einmal.
    final kindPool = <DailyQuestTaskKind>[
      DailyQuestTaskKind.coloring,
      DailyQuestTaskKind.placeSticker,
      if (allowWatchAd) DailyQuestTaskKind.watchAd,
      if (puzzles.isNotEmpty) DailyQuestTaskKind.puzzle,
      // Dot Art: max. 1 Task/Tag, und nur an erlaubten Tagen (außer offenes Bild).
      if (allowPixelQuest && pixelReady.isNotEmpty)
        (rng.nextBool()
            ? DailyQuestTaskKind.pixel
            : DailyQuestTaskKind.pixelThreeStar),
      if (finished.isNotEmpty) DailyQuestTaskKind.recolor,
      if (coloring.isNotEmpty) DailyQuestTaskKind.coloringThreeStar,
      if (events.isNotEmpty) DailyQuestTaskKind.eventFinish,
      if (hasStarLockedContent) DailyQuestTaskKind.unlockChoice,
      if (adventDoorAvailable) DailyQuestTaskKind.adventDoor,
    ]..shuffle(rng);

    // Offenes Dot Art → „fertigmachen“ trotzdem priorisieren (auch an Off-Tagen).
    if (hasOpenPixel) {
      kindPool.remove(DailyQuestTaskKind.pixel);
      kindPool.remove(DailyQuestTaskKind.pixelThreeStar);
      kindPool.insert(0, DailyQuestTaskKind.pixel);
    }

    for (final kind in kindPool) {
      if (out.length >= targetCount) break;
      final task = buildKind(kind);
      if (task != null) out.add(task);
    }

    // Auffüllen nur mit Coloring (kein zweites Puzzle).
    while (out.length < targetCount && colorIdx < coloring.length) {
      final task = buildKind(DailyQuestTaskKind.coloring);
      if (task == null) break;
      out.add(task);
    }

    out.shuffle(rng);
    return out.toList(growable: false);
  }

  DailyQuestTask? _matchingColoring(String id, {required int rating}) {
    for (final t in _tasks) {
      if (t.pageId != id) continue;
      if (t.isColoringThreeStar) {
        if (rating >= 3) return t;
        continue;
      }
      if (t.isColoring || t.isRecolor || t.isEventFinish) return t;
    }
    return null;
  }

  /// Heutige Daily-Aufgabe (Ausmalen oder Puzzle) — keine normalen Abschluss-Sterne.
  bool isTodaysQuestTarget(String pageId, {required bool coloring}) {
    for (final t in _tasks) {
      if (t.pageId != pageId) continue;
      if (coloring &&
          (t.isColoring ||
              t.isPlaceSticker ||
              t.isRecolor ||
              t.isColoringThreeStar ||
              t.isEventFinish)) {
        return true;
      }
      if (!coloring && t.isPuzzle) return true;
    }
    return false;
  }

  bool _puzzleMeets(DailyQuestTask t, PuzzleTier tier) {
    if (!t.isPuzzle) return false;
    return switch (t.puzzleRequirement) {
      DailyQuestPuzzleRequirement.any => tier == PuzzleTier.easy,
      DailyQuestPuzzleRequirement.mediumOrHard => tier == PuzzleTier.medium,
      DailyQuestPuzzleRequirement.hardOnly => tier == PuzzleTier.expert,
    };
  }

  Future<bool> _markSlotDone(DailyQuestTask task) async {
    if (!_ready || isCompletedToday) return false;
    final key = _slotDoneKey(task);
    if (_done.contains(key)) return false;
    _done.add(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_doneKey, _done.toList(growable: false)..sort());
    var justCompleted = false;
    if (_tasks.isNotEmpty &&
        _tasks.every((t) => _done.contains(_slotDoneKey(t)))) {
      _completedDay = _todayKey();
      await prefs.setString(_completedDayKey, _completedDay!);
      justCompleted = true;
    }
    notifyListeners();
    return justCompleted;
  }

  /// Ausmalen fertig → passende Daily-Aufgabe abhaken.
  Future<bool> markColoringDone(String id, {int rating = 1}) async {
    final task = _matchingColoring(id, rating: rating);
    if (task == null) return false;
    return _markSlotDone(task);
  }

  /// Sticker auf dem Bild platziert.
  Future<bool> markStickerPlaced(String pageId) async {
    var justCompleted = false;
    for (final t in _tasks) {
      if (!t.isPlaceSticker || t.pageId != pageId) continue;
      if (await _markSlotDone(t)) justCompleted = true;
    }
    return justCompleted;
  }

  /// Pixelart-Bild fertig.
  Future<bool> markPixelDone(String pageId, {int rating = 1}) async {
    var justCompleted = false;
    for (final t in _tasks) {
      if (t.pageId != pageId) continue;
      if (t.isPixelThreeStar) {
        if (rating < 3) continue;
        if (await _markSlotDone(t)) justCompleted = true;
        continue;
      }
      if (!t.isPixel) continue;
      if (await _markSlotDone(t)) justCompleted = true;
    }
    return justCompleted;
  }

  /// Ein gesperrtes Motiv der Wahl freigeschaltet.
  Future<bool> markUnlockChoiceDone() async {
    var justCompleted = false;
    for (final t in _tasks) {
      if (!t.isUnlockChoice) continue;
      if (await _markSlotDone(t)) justCompleted = true;
    }
    return justCompleted;
  }

  /// Rewarded-Video für Daily geschaut.
  Future<bool> markWatchAdDone() async {
    var justCompleted = false;
    for (final t in _tasks) {
      if (!t.isWatchAd) continue;
      if (await _markSlotDone(t)) justCompleted = true;
    }
    return justCompleted;
  }

  /// Advents-Tür geöffnet.
  Future<bool> markAdventDoorDone() async {
    var justCompleted = false;
    for (final t in _tasks) {
      if (!t.isAdventDoor) continue;
      if (await _markSlotDone(t)) justCompleted = true;
    }
    return justCompleted;
  }

  /// Puzzle fertig → alle passenden Slots abhaken (medium+).
  Future<bool> markPuzzleDone(String id, {required PuzzleTier tier}) async {
    var justCompleted = false;
    for (final t in _tasks) {
      if (t.pageId != id || !_puzzleMeets(t, tier)) continue;
      if (await _markSlotDone(t)) justCompleted = true;
    }
    return justCompleted;
  }

  int get doneCount =>
      _tasks.where((t) => _done.contains(_slotDoneKey(t))).length;

  bool get stickerAwardedToday =>
      _stickerTierDay == _todayKey() && _stickersClaimed > 0;

  void _loadStickerTier(String? raw) {
    _stickerTierDay = null;
    _stickersClaimed = 0;
    if (raw == null || raw.isEmpty) return;
    final parts = raw.split('|');
    if (parts.length != 2) return;
    _stickerTierDay = parts[0];
    _stickersClaimed = int.tryParse(parts[1]) ?? 0;
  }

  Future<void> _persistStickerTier(SharedPreferences prefs) async {
    final today = _todayKey();
    _stickerTierDay = today;
    await prefs.setString(_stickerTierKey, '$today|$_stickersClaimed');
  }

  void _loadPendingHub(String? raw) {
    _pendingHubOpenList = false;
    _pendingHubStickers = 0;
    _pendingHubStars = 0;
    if (raw == null || raw.isEmpty) return;
    final parts = raw.split('|');
    if (parts.length < 4) return;
    if (parts[0] != _todayKey()) return;
    _pendingHubOpenList = parts[1] == '1';
    _pendingHubStickers = int.tryParse(parts[2]) ?? 0;
    _pendingHubStars = int.tryParse(parts[3]) ?? 0;
  }

  Future<void> _persistPendingHub(SharedPreferences prefs) async {
    final today = _todayKey();
    if (!_pendingHubOpenList &&
        _pendingHubStickers <= 0 &&
        _pendingHubStars <= 0) {
      await prefs.remove(_pendingHubKey);
      return;
    }
    final open = _pendingHubOpenList ? '1' : '0';
    await prefs.setString(
      _pendingHubKey,
      '$today|$open|$_pendingHubStickers|$_pendingHubStars',
    );
  }

  bool get hasPendingHubCelebration =>
      _pendingHubOpenList ||
      _pendingHubStickers > 0 ||
      _pendingHubStars > 0;

  /// Hub holt ausstehende Daily-Belohnung (Liste + Sticker + Sterne).
  Future<({bool openList, int stickers, int stars})?>
      takePendingHubCelebration() async {
    if (!hasPendingHubCelebration) return null;
    final result = (
      openList: _pendingHubOpenList,
      stickers: _pendingHubStickers,
      stars: _pendingHubStars,
    );
    _pendingHubOpenList = false;
    _pendingHubStickers = 0;
    _pendingHubStars = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingHubKey);
    notifyListeners();
    return result;
  }

  /// Alle heutigen Tasks fertig → Belohnung erst im Hub (skaliert nach Anzahl).
  Future<void> claimProgressRewards(StarWalletStore wallet) async {
    if (_tasks.isEmpty || !allTasksDone) return;

    final today = _todayKey();
    if (_stickerTierDay != today) {
      _stickerTierDay = today;
      _stickersClaimed = 0;
    }
    final prefs = await SharedPreferences.getInstance();
    var stickers = 0;
    var stars = 0;

    // 1 Task → 1 Sticker / 5★ · 2 → 2 / 8★ · 3 → 2 / 10★
    final stickerTarget = _tasks.length >= 2 ? 2 : 1;
    final starTarget = switch (_tasks.length) {
      1 => 5,
      2 => 8,
      _ => completeStarReward,
    };

    if (_stickersClaimed < stickerTarget) {
      stickers = stickerTarget - _stickersClaimed;
      _stickersClaimed = stickerTarget;
      await _persistStickerTier(prefs);
    }
    if (_starsAwardedDay != today) {
      _starsAwardedDay = today;
      await prefs.setString(_starsAwardedKey, today);
      await wallet.addStars(starTarget);
      stars = starTarget;
    }

    if (stickers <= 0 && stars <= 0) return;

    _pendingHubOpenList = true;
    _pendingHubStickers += stickers;
    _pendingHubStars += stars;
    await _persistPendingHub(prefs);
    notifyListeners();
  }

  bool get allTasksDone =>
      _tasks.isNotEmpty &&
      _tasks.every((t) => _done.contains(_slotDoneKey(t)));

  /// Nach Hot-Reload: kaputte In-Memory-Tasks neu laden.
  Future<void> repairIfNeeded({
    List<String> freeColoringIds = const [],
    List<String> freePuzzleIds = const [],
    List<String> pixelReadyIds = const [],
    List<String> pixelInProgressIds = const [],
    List<String> finishedColoringIds = const [],
    List<String> eventColoringIds = const [],
    bool hasStarLockedContent = false,
    bool adventDoorAvailable = false,
  }) async {
    if (_tasksValid(_tasks) || isCompletedToday) return;
    await load(
      freeColoringIds: freeColoringIds,
      freePuzzleIds: freePuzzleIds,
      pixelReadyIds: pixelReadyIds,
      pixelInProgressIds: pixelInProgressIds,
      finishedColoringIds: finishedColoringIds,
      eventColoringIds: eventColoringIds,
      hasStarLockedContent: hasStarLockedContent,
      adventDoorAvailable: adventDoorAvailable,
    );
  }

  static Future<List<String>> activeEventColoringIds() async {
    final tags = await EventTags.load();
    final ids = <String>{};
    for (final e in tags.activeEvents()) {
      ids.addAll(e.coloringIds);
    }
    return ids.toList(growable: false);
  }

  static bool adventDoorAvailableNow() {
    if (!AdventService.canOpenDoors()) return false;
    return AdventService.instance.openableUnopenedCount > 0;
  }

  static bool hasStarLockedContent({
    required StarWalletStore wallet,
    required List<String> allColoring,
    required List<String> allPuzzle,
  }) {
    for (final id in allColoring) {
      if (wallet.requiresStars(id, FavoriteKind.coloring)) return true;
    }
    for (final id in allPuzzle) {
      if (wallet.requiresStars(id, FavoriteKind.puzzle)) return true;
    }
    return false;
  }

  Future<void> openOverlay(BuildContext context) async {
    // Nach Abschluss heute keine neuen Tasks mehr erzeugen.
    if (!_tasksValid(_tasks) && !isCompletedToday) {
      final coloring = await loadColoringPages(shuffle: false);
      final puzzles = await loadPuzzleImages(shuffle: false);
      final pools = await freePools(
        allColoring: [for (final p in coloring) p.id],
        allPuzzle: [for (final p in puzzles) p.id],
      );
      if (!context.mounted) return;
      final pixelIds =
          context.read<PixelReadyStore>().ids.toList(growable: false);
      final pixelInProgress =
          context.read<PixelProgressStore>().inProgressIds;
      final wallet = context.read<StarWalletStore>();
      final hasLocked = hasStarLockedContent(
        wallet: wallet,
        allColoring: pools.coloring,
        allPuzzle: pools.puzzle,
      );
      // Auch Economy-/Advent-Locks außerhalb der Free-Pools prüfen.
      final hasLockedAny = hasLocked ||
          hasStarLockedContent(
            wallet: wallet,
            allColoring: [for (final p in coloring) p.id],
            allPuzzle: [for (final p in puzzles) p.id],
          );
      final eventIds = await activeEventColoringIds();
      final today = _todayKey();
      final prefs = await SharedPreferences.getInstance();
      _day = today;
      _tasks = _generate(
        freeColoringIds: pools.coloring,
        freePuzzleIds: pools.puzzle,
        pixelReadyIds: pixelIds,
        pixelInProgressIds: pixelInProgress,
        finishedColoringIds: pixelIds,
        eventColoringIds: eventIds,
        hasStarLockedContent: hasLockedAny,
        adventDoorAvailable: adventDoorAvailableNow(),
        seed: today,
      );
      _done.clear();
      await prefs.setString(_dayKey, today);
      await prefs.setStringList(_tasksKey, _encodeTasks(_tasks));
      await prefs.setStringList(_doneKey, const []);
      _ready = true;
      notifyListeners();
    }
    if (!context.mounted) return;
    return DailyQuestOverlay.show(context);
  }

  static Future<({List<String> coloring, List<String> puzzle})> freePools({
    required List<String> allColoring,
    required List<String> allPuzzle,
  }) async {
    final eco = await StarEconomy.load();
    final lockedC = eco.lockedIds(FavoriteKind.coloring);
    final lockedP = eco.lockedIds(FavoriteKind.puzzle);
    return (
      coloring: [
        for (final id in allColoring)
          if (!lockedC.contains(id)) id,
      ],
      puzzle: [
        for (final id in allPuzzle)
          if (!lockedP.contains(id)) id,
      ],
    );
  }
}
