import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/coloring_pages_loader.dart';
import '../data/puzzle_images_loader.dart';
import '../data/star_economy.dart';
import '../models/puzzle_settings.dart';
import '../providers/favorites_store.dart';
import '../providers/pixel_ready_store.dart';
import '../providers/star_wallet_store.dart';
import '../widgets/daily_quest_overlay.dart';

enum DailyQuestTaskKind { coloring, puzzle, placeSticker, pixel, recolor }

/// Puzzle-Anforderung für die Aufgabe.
enum DailyQuestPuzzleRequirement {
  /// Beliebige Teilezahl / Schwierigkeit.
  any,

  /// Mindestens Medium oder Schwer (Pro).
  mediumOrHard,
}

class DailyQuestTask {
  const DailyQuestTask({
    required this.slotId,
    required this.kind,
    required this.pageId,
    this.puzzleRequirement = DailyQuestPuzzleRequirement.any,
  });

  /// Stabiler Slot (color / puzzle / sticker / pixel / recolor).
  final String slotId;
  final DailyQuestTaskKind kind;
  final String pageId;
  final DailyQuestPuzzleRequirement puzzleRequirement;

  bool get isColoring => kind == DailyQuestTaskKind.coloring;
  bool get isPuzzle => kind == DailyQuestTaskKind.puzzle;
  bool get isPlaceSticker => kind == DailyQuestTaskKind.placeSticker;
  bool get isPixel => kind == DailyQuestTaskKind.pixel;
  bool get isRecolor => kind == DailyQuestTaskKind.recolor;
}

/// Tagesquest: immer bis zu 3 abwechslungsreiche Aufgaben.
class DailyQuestService extends ChangeNotifier {
  DailyQuestService();

  static const _dayKey = 'daily_quest_day_v1';
  static const _tasksKey = 'daily_quest_tasks_v2';
  static const _doneKey = 'daily_quest_done_v2';
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

  Future<void> load({
    List<String> freeColoringIds = const [],
    List<String> freePuzzleIds = const [],
    List<String> pixelReadyIds = const [],
    List<String> finishedColoringIds = const [],
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
        finishedColoringIds: finishedColoringIds,
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
          finishedColoringIds: finishedColoringIds,
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
              DailyQuestTaskKind.coloring => 'c',
            },
            t.pageId,
            t.puzzleRequirement == DailyQuestPuzzleRequirement.mediumOrHard
                ? 'mh'
                : 'any',
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
        _ => DailyQuestTaskKind.coloring,
      };
      final req = parts[3] == 'mh'
          ? DailyQuestPuzzleRequirement.mediumOrHard
          : DailyQuestPuzzleRequirement.any;
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

  /// Bis zu 3 zufällige Aufgaben aus dem verfügbaren Pool (nicht immer Puzzle).
  /// Fertige Colorings/Pixel bleiben im Pool und können erneut gezogen werden.
  List<DailyQuestTask> _generate({
    required List<String> freeColoringIds,
    required List<String> freePuzzleIds,
    required String seed,
    List<String> pixelReadyIds = const [],
    List<String> finishedColoringIds = const [],
  }) {
    final rng = Random(seed.hashCode);
    final coloring = [...freeColoringIds]..shuffle(rng);
    final puzzles = [...freePuzzleIds]..shuffle(rng);
    // Pixel-Dailys: fertige Bilder beliebig oft wiederverwenden.
    final pixelReady = [...pixelReadyIds]..shuffle(rng);
    final finished = [
      ...{
        ...finishedColoringIds,
        ...pixelReadyIds,
      },
    ]..shuffle(rng);

    final candidates = <DailyQuestTask>[];
    var colorIdx = 0;
    var puzzleIdx = 0;
    var pixelIdx = 0;
    var recolorIdx = 0;

    void takeColor(String slot) {
      if (colorIdx >= coloring.length) return;
      candidates.add(
        DailyQuestTask(
          slotId: slot,
          kind: DailyQuestTaskKind.coloring,
          pageId: coloring[colorIdx++],
        ),
      );
    }

    void takePuzzle(String slot, DailyQuestPuzzleRequirement req) {
      if (puzzleIdx >= puzzles.length) return;
      candidates.add(
        DailyQuestTask(
          slotId: slot,
          kind: DailyQuestTaskKind.puzzle,
          pageId: puzzles[puzzleIdx++],
          puzzleRequirement: req,
        ),
      );
    }

    void takeSticker(String slot) {
      if (colorIdx >= coloring.length && coloring.isEmpty) return;
      final id = colorIdx < coloring.length
          ? coloring[colorIdx++]
          : (coloring.isNotEmpty ? coloring.first : null);
      if (id == null) return;
      candidates.add(
        DailyQuestTask(
          slotId: slot,
          kind: DailyQuestTaskKind.placeSticker,
          pageId: id,
        ),
      );
    }

    void takePixel(String slot) {
      if (pixelIdx >= pixelReady.length) return;
      candidates.add(
        DailyQuestTask(
          slotId: slot,
          kind: DailyQuestTaskKind.pixel,
          pageId: pixelReady[pixelIdx++],
        ),
      );
    }

    void takeRecolor(String slot) {
      if (recolorIdx >= finished.length) return;
      candidates.add(
        DailyQuestTask(
          slotId: slot,
          kind: DailyQuestTaskKind.recolor,
          pageId: finished[recolorIdx++],
        ),
      );
    }

    // Pool von möglichen Typen — daraus 3 ziehen.
    final builders = <void Function()>[
      () => takeColor('color_${candidates.length}'),
      () => takePuzzle('puzzle_any_${candidates.length}', DailyQuestPuzzleRequirement.any),
      () => takePuzzle(
            'puzzle_mh_${candidates.length}',
            DailyQuestPuzzleRequirement.mediumOrHard,
          ),
      () => takeSticker('sticker_${candidates.length}'),
      if (pixelReady.isNotEmpty) () => takePixel('pixel_${candidates.length}'),
      if (finished.isNotEmpty) () => takeRecolor('recolor_${candidates.length}'),
    ]..shuffle(rng);

    for (final build in builders) {
      if (candidates.length >= 3) break;
      final before = candidates.length;
      build();
      // Duplikat-Slots vermeiden: nur behalten wenn gewachsen.
      if (candidates.length == before) continue;
    }

    // Auffüllen falls Pool dünn.
    while (candidates.length < 3 && colorIdx < coloring.length) {
      takeColor('color_fill_${candidates.length}');
    }
    while (candidates.length < 3 && puzzleIdx < puzzles.length) {
      takePuzzle(
        'puzzle_fill_${candidates.length}',
        DailyQuestPuzzleRequirement.any,
      );
    }

    candidates.shuffle(rng);
    return candidates.take(3).toList(growable: false);
  }

  DailyQuestTask? _matchingColoring(String id) {
    for (final t in _tasks) {
      if ((t.isColoring || t.isRecolor) && t.pageId == id) return t;
    }
    return null;
  }

  /// Heutige Daily-Aufgabe (Ausmalen oder Puzzle) — keine normalen Abschluss-Sterne.
  bool isTodaysQuestTarget(String pageId, {required bool coloring}) {
    for (final t in _tasks) {
      if (t.pageId != pageId) continue;
      if (coloring && (t.isColoring || t.isPlaceSticker || t.isRecolor)) {
        return true;
      }
      if (!coloring && t.isPuzzle) return true;
    }
    return false;
  }

  bool _puzzleMeets(DailyQuestTask t, PuzzleTier tier) {
    if (!t.isPuzzle) return false;
    if (t.puzzleRequirement == DailyQuestPuzzleRequirement.any) return true;
    return tier == PuzzleTier.medium || tier == PuzzleTier.expert;
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
  Future<bool> markColoringDone(String id) async {
    final task = _matchingColoring(id);
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
  Future<bool> markPixelDone(String pageId) async {
    var justCompleted = false;
    for (final t in _tasks) {
      if (!t.isPixel || t.pageId != pageId) continue;
      if (await _markSlotDone(t)) justCompleted = true;
    }
    return justCompleted;
  }

  /// Puzzle fertig → alle passenden Slots abhaken (any / medium+).
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

  /// Alle 3 fertig → Belohnung erst im Hub (2 Sticker + 10 Sterne).
  Future<void> claimProgressRewards(StarWalletStore wallet) async {
    if (_tasks.length < 3 || !allTasksDone) return;

    final today = _todayKey();
    if (_stickerTierDay != today) {
      _stickerTierDay = today;
      _stickersClaimed = 0;
    }
    final prefs = await SharedPreferences.getInstance();
    var stickers = 0;
    var stars = 0;

    if (_stickersClaimed < 2) {
      stickers = 2 - _stickersClaimed;
      _stickersClaimed = 2;
      await _persistStickerTier(prefs);
    }
    if (_starsAwardedDay != today) {
      _starsAwardedDay = today;
      await prefs.setString(_starsAwardedKey, today);
      await wallet.addStars(completeStarReward);
      stars = completeStarReward;
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
    List<String> finishedColoringIds = const [],
  }) async {
    if (_tasksValid(_tasks) || isCompletedToday) return;
    await load(
      freeColoringIds: freeColoringIds,
      freePuzzleIds: freePuzzleIds,
      pixelReadyIds: pixelReadyIds,
      finishedColoringIds: finishedColoringIds,
    );
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
      final today = _todayKey();
      final prefs = await SharedPreferences.getInstance();
      _day = today;
      _tasks = _generate(
        freeColoringIds: pools.coloring,
        freePuzzleIds: pools.puzzle,
        pixelReadyIds: pixelIds,
        finishedColoringIds: pixelIds,
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
