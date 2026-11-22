import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/favorites_store.dart';
import '../providers/star_wallet_store.dart';
import '../widgets/star_unlock_dialog.dart';
import 'event_content_gate.dart';

/// Stern-Freischaltung, danach ggf. Event-Interstitial.
class StarContentGate {
  StarContentGate._();

  static Future<bool> ensureUnlocked(
    BuildContext context, {
    required String id,
    required FavoriteKind kind,
  }) async {
    final wallet = context.read<StarWalletStore>();
    if (!wallet.isReady) await wallet.load();
    if (!context.mounted) return false;

    if (wallet.requiresStars(id, kind)) {
      final ok = await StarUnlockDialog.show(
        context,
        id: id,
        kind: kind,
      );
      if (!ok || !context.mounted) return false;
    }

    return EventContentGate.ensureUnlocked(
      context,
      id: id,
      kind: kind,
    );
  }
}
