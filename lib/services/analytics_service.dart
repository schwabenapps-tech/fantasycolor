import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Leichte Analytics-Hülle — keine User-IDs, nur App-Nutzung.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> initialize() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
    } catch (e, st) {
      debugPrint('AnalyticsService.initialize failed: $e\n$st');
    }
  }

  void logScreen(String name) {
    unawaited(_safe(() => _analytics.logScreenView(screenName: name)));
  }

  void logOpenWorld(String world) {
    unawaited(
      _safe(
        () => _analytics.logEvent(
          name: 'open_world',
          parameters: {'world': world},
        ),
      ),
    );
  }

  void logStartColoring(String pageId) {
    unawaited(
      _safe(
        () => _analytics.logEvent(
          name: 'start_coloring',
          parameters: {'page_id': pageId},
        ),
      ),
    );
  }

  void logCompleteColoring(String pageId) {
    unawaited(
      _safe(
        () => _analytics.logEvent(
          name: 'complete_coloring',
          parameters: {'page_id': pageId},
        ),
      ),
    );
  }

  void logStartPuzzle(String puzzleId) {
    unawaited(
      _safe(
        () => _analytics.logEvent(
          name: 'start_puzzle',
          parameters: {'puzzle_id': puzzleId},
        ),
      ),
    );
  }

  void logCompletePuzzle(String puzzleId) {
    unawaited(
      _safe(
        () => _analytics.logEvent(
          name: 'complete_puzzle',
          parameters: {'puzzle_id': puzzleId},
        ),
      ),
    );
  }

  void logMuteToggled({required bool muted}) {
    unawaited(
      _safe(
        () => _analytics.logEvent(
          name: 'mute_toggled',
          parameters: {'muted': muted ? 1 : 0},
        ),
      ),
    );
  }

  void logStickerUnlock(String stickerId, {required String source}) {
    unawaited(
      _safe(
        () => _analytics.logEvent(
          name: 'sticker_unlock',
          parameters: {
            'sticker_id': stickerId,
            'source': source,
          },
        ),
      ),
    );
  }

  void logDailyBoxClaim(String stickerId) {
    unawaited(
      _safe(
        () => _analytics.logEvent(
          name: 'daily_box_claim',
          parameters: {'sticker_id': stickerId},
        ),
      ),
    );
  }

  void logStickerPackExport(int count) {
    unawaited(
      _safe(
        () => _analytics.logEvent(
          name: 'sticker_pack_export',
          parameters: {'count': count},
        ),
      ),
    );
  }

  Future<void> _safe(Future<void> Function() op) async {
    try {
      await op();
    } catch (e, st) {
      debugPrint('AnalyticsService failed: $e\n$st');
    }
  }
}
