import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';

enum FeedbackSatisfaction { good, okay, bad }

enum FeedbackFavorite { coloring, puzzle, pixel, daily }

/// Einmalige Zufriedenheits-Umfrage.
///
/// Trigger: 3× Ausmalen mit 3★ **und** mindestens ein fertiges Puzzle.
/// Dot Art zählt nicht.
///
/// Zähler werden beim Level-Abschluss persistiert; das Overlay kann später
/// (Fertig-Button oder Back während der Feier) erscheinen.
class FeedbackSurveyStore extends ChangeNotifier {
  FeedbackSurveyStore();

  static const _coloringThreeStarKey = 'feedback_coloring_three_star_count_v1';
  static const _puzzleDoneKey = 'feedback_puzzle_done_v1';
  static const _doneKey = 'feedback_survey_done_v1';
  static const _reviewAskedKey = 'feedback_review_asked_v1';

  /// So viele Ausmalen-3★ bevor die Umfrage infrage kommt.
  static const triggerAfterColoringThreeStars = 3;

  int _coloringThreeStarCount = 0;
  bool _puzzleDone = false;
  bool _done = false;
  bool _reviewAsked = false;
  bool _ready = false;

  bool get isReady => _ready;
  bool get isDone => _done;
  int get coloringThreeStarCount => _coloringThreeStarCount;
  bool get hasCompletedPuzzle => _puzzleDone;

  /// Bereit zum Anzeigen (ohne Zähler zu ändern).
  bool get shouldOfferSurvey =>
      _ready &&
      !_done &&
      _coloringThreeStarCount >= triggerAfterColoringThreeStars &&
      _puzzleDone;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Alt: generischer 3★-Zähler → als Coloring-Zähler übernehmen.
    final legacy = prefs.getInt('feedback_three_star_count_v1');
    _coloringThreeStarCount =
        prefs.getInt(_coloringThreeStarKey) ?? legacy ?? 0;
    _puzzleDone = prefs.getBool(_puzzleDoneKey) ?? false;
    _done = prefs.getBool(_doneKey) ?? false;
    _reviewAsked = prefs.getBool(_reviewAskedKey) ?? false;
    _ready = true;
    notifyListeners();
  }

  /// Beim Ausmalen-Abschluss mit 3★ — nur zählen, nicht anzeigen.
  Future<void> recordColoringThreeStar() async {
    if (!_ready) await load();
    if (_done) return;
    _coloringThreeStarCount += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_coloringThreeStarKey, _coloringThreeStarCount);
    notifyListeners();
  }

  /// Beim Puzzle-Abschluss — nur merken, nicht anzeigen.
  Future<void> recordPuzzleCompleted() async {
    if (!_ready) await load();
    if (_done) return;
    if (_puzzleDone) return;
    _puzzleDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_puzzleDoneKey, true);
    notifyListeners();
  }

  Future<void> markDismissed() async {
    if (!_ready) await load();
    if (_done) return;
    _done = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
    AnalyticsService.instance.logFeedbackSurveyDismissed();
    notifyListeners();
  }

  Future<void> submit({
    required FeedbackSatisfaction satisfaction,
    FeedbackFavorite? favorite,
    String note = '',
  }) async {
    if (!_ready) await load();
    _done = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);

    final trimmed = note.trim();
    // Freitext nur gekürzt in Analytics (Firebase-String-Limit ~100).
    final notePreview = trimmed.isEmpty
        ? null
        : (trimmed.length <= 100 ? trimmed : '${trimmed.substring(0, 97)}...');
    AnalyticsService.instance.logFeedbackSurveySubmitted(
      satisfaction: satisfaction.name,
      favorite: favorite?.name,
      hasNote: trimmed.isNotEmpty,
      notePreview: notePreview,
    );

    if (satisfaction == FeedbackSatisfaction.good && !_reviewAsked) {
      _reviewAsked = true;
      await prefs.setBool(_reviewAskedKey, true);
      await _maybeRequestStoreReview();
    }
    notifyListeners();
  }

  Future<void> _maybeRequestStoreReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        AnalyticsService.instance.logInAppReviewPrompted();
      }
    } catch (e, st) {
      debugPrint('InAppReview failed: $e\n$st');
    }
  }

  /// Nur Debug/Test: Umfrage wieder anzeigbar machen.
  Future<void> debugReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_coloringThreeStarKey);
    await prefs.remove('feedback_three_star_count_v1');
    await prefs.remove(_puzzleDoneKey);
    await prefs.remove(_doneKey);
    await prefs.remove(_reviewAskedKey);
    _coloringThreeStarCount = 0;
    _puzzleDone = false;
    _done = false;
    _reviewAsked = false;
    _ready = true;
    notifyListeners();
  }
}
