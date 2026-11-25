import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';

enum FeedbackSatisfaction { good, okay, bad }

enum FeedbackFavorite { coloring, puzzle, pixel, daily }

/// Einmalige Zufriedenheits-Umfrage.
///
/// Trigger: 2× Ausmalen mit 3★ **und** 2× Puzzle mit 3★.
/// Dot Art zählt nicht.
///
/// Zähler werden beim Level-Abschluss persistiert; das Overlay kann später
/// (Fertig-Button oder Back während der Feier) erscheinen.
class FeedbackSurveyStore extends ChangeNotifier {
  FeedbackSurveyStore();

  static const _coloringThreeStarKey = 'feedback_coloring_three_star_count_v1';
  static const _puzzleThreeStarKey = 'feedback_puzzle_three_star_count_v1';
  static const _doneKey = 'feedback_survey_done_v1';
  static const _reviewAskedKey = 'feedback_review_asked_v1';

  static const triggerAfterColoringThreeStars = 2;
  static const triggerAfterPuzzleThreeStars = 2;

  int _coloringThreeStarCount = 0;
  int _puzzleThreeStarCount = 0;
  bool _done = false;
  bool _reviewAsked = false;
  bool _ready = false;

  bool get isReady => _ready;
  bool get isDone => _done;
  int get coloringThreeStarCount => _coloringThreeStarCount;
  int get puzzleThreeStarCount => _puzzleThreeStarCount;

  /// Bereit zum Anzeigen (ohne Zähler zu ändern).
  bool get shouldOfferSurvey =>
      _ready &&
      !_done &&
      _coloringThreeStarCount >= triggerAfterColoringThreeStars &&
      _puzzleThreeStarCount >= triggerAfterPuzzleThreeStars;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Alt: generischer 3★-Zähler → als Coloring-Zähler übernehmen.
    final legacyColoring = prefs.getInt('feedback_three_star_count_v1');
    _coloringThreeStarCount =
        prefs.getInt(_coloringThreeStarKey) ?? legacyColoring ?? 0;
    // Alt: nur „ein Puzzle fertig“ → als 1× Puzzle-3★ werten, falls gesetzt.
    final legacyPuzzleDone = prefs.getBool('feedback_puzzle_done_v1') ?? false;
    _puzzleThreeStarCount = prefs.getInt(_puzzleThreeStarKey) ??
        (legacyPuzzleDone ? 1 : 0);
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

  /// Beim Puzzle-Abschluss mit 3★ — nur zählen, nicht anzeigen.
  Future<void> recordPuzzleThreeStar() async {
    if (!_ready) await load();
    if (_done) return;
    _puzzleThreeStarCount += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_puzzleThreeStarKey, _puzzleThreeStarCount);
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
}
