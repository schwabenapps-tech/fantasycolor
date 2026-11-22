import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/star_wallet_store.dart';
import '../providers/sticker_collection_store.dart';
import 'star_earn_overlay.dart';
import 'sticker_daily_gift_overlay.dart';

/// Daily-Belohnung im Hub: Geschenkbox(en), danach Sterne-Show.
class DailyQuestReward {
  DailyQuestReward._();

  static Future<void> maybeShow(
    BuildContext context, {
    int stickerCount = 1,
    int bonusStars = 0,
  }) async {
    final store = context.read<StickerCollectionStore>();
    await store.load();
    if (!context.mounted) return;

    final t = AppStrings.of(context);
    for (var i = 0; i < stickerCount; i++) {
      if (!context.mounted) return;
      final choices = store.offerChoices(count: 3);
      if (choices.isEmpty) break;
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        pageBuilder: (ctx, _, _) => StickerDailyGiftOverlay(
          choices: choices,
          isDaily: false,
          source: 'daily_quest',
          title: t.dailySurprise,
          subtitle: t.pickBoxToday,
          revealTitle: t.dailyReward,
          onClosed: () => Navigator.of(ctx).maybePop(),
        ),
      );
    }

    if (!context.mounted) return;
    if (bonusStars > 0) {
      final total = context.read<StarWalletStore>().balance;
      await StarEarnOverlay.show(
        context,
        amount: bonusStars,
        newTotal: total,
      );
    }
  }
}
