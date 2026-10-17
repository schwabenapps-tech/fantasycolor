import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tages-Streak für Spielaktivität (Ausmalen fertig, Puzzle, Daily).
class StreakService extends ChangeNotifier {
  StreakService._();

  static final StreakService instance = StreakService._();

  static const _countKey = 'play_streak_count_v1';
  static const _lastDayKey = 'play_streak_last_day_v1';

  int _count = 0;
  String? _lastDay;
  bool _ready = false;

  int get count => _count;
  bool get isReady => _ready;

  /// Heute schon gezählt (Ausmalen/Puzzle/Daily).
  bool get playedToday => _lastDay == dayKey();

  static String dayKey([DateTime? now]) {
    final n = now ?? DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _count = prefs.getInt(_countKey) ?? 0;
      _lastDay = prefs.getString(_lastDayKey);
      _ready = true;
      // Unterbrochene Streaks auf 0 setzen, wenn gestern nicht gespielt.
      final today = dayKey();
      final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
      if (_lastDay != null &&
          _lastDay != today &&
          _lastDay != yesterday &&
          _count > 0) {
        _count = 0;
        await prefs.setInt(_countKey, 0);
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('StreakService.load failed: $e\n$st');
      _ready = true;
    }
  }

  /// Zählt den heutigen Tag einmal. Gibt true, wenn der Streak gestiegen ist.
  Future<bool> recordPlayDay() async {
    if (!_ready) await load();
    final today = dayKey();
    if (_lastDay == today) return false;

    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    if (_lastDay == yesterday) {
      _count += 1;
    } else {
      _count = 1;
    }
    _lastDay = today;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_countKey, _count);
      await prefs.setString(_lastDayKey, today);
    } catch (e, st) {
      debugPrint('StreakService.save failed: $e\n$st');
    }
    notifyListeners();
    return true;
  }
}
