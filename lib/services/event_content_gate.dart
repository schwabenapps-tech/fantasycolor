import 'package:flutter/widgets.dart';

import '../data/event_tags.dart';
import '../providers/favorites_store.dart';
import 'ads_service.dart';

/// Motive des zuletzt abgelaufenen Events: **jedes** Öffnen braucht Werbung.
class EventContentGate {
  EventContentGate._();

  static bool isGatedId(
    EventTags tags,
    String id, {
    required FavoriteKind kind,
  }) {
    final last = tags.lastPastEvent();
    if (last == null) return false;
    return kind == FavoriteKind.puzzle
        ? last.puzzleIds.contains(id)
        : last.coloringIds.contains(id);
  }

  /// Zeigt bei Last-Event-Motiven jedes Mal ein Interstitial, dann true.
  static Future<bool> ensureUnlocked(
    BuildContext context, {
    required String id,
    required FavoriteKind kind,
  }) async {
    final tags = await EventTags.load();
    if (!isGatedId(tags, id, kind: kind)) return true;

    await AdsService.showEventContentUnlockInterstitial();
    if (!context.mounted) return false;
    return true;
  }
}
