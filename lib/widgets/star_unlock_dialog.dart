import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/favorites_store.dart';
import '../providers/star_wallet_store.dart';
import '../services/ads_service.dart';
import '../services/daily_quest_service.dart';
import 'earn_stars_sheet.dart';
import 'star_balance_pill.dart';
import 'star_earn_overlay.dart';

class StarUnlockDialog {
  StarUnlockDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String id,
    required FavoriteKind kind,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _StarUnlockBody(id: id, kind: kind),
    );
    return result == true;
  }
}

class _StarUnlockBody extends StatefulWidget {
  const _StarUnlockBody({required this.id, required this.kind});

  final String id;
  final FavoriteKind kind;

  @override
  State<_StarUnlockBody> createState() => _StarUnlockBodyState();
}

class _StarUnlockBodyState extends State<_StarUnlockBody> {
  bool _busy = false;

  Future<void> _buy() async {
    if (_busy) return;
    setState(() => _busy = true);
    final wallet = context.read<StarWalletStore>();
    final ok = await wallet.unlockWithStars(widget.id, widget.kind);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _watchAd() async {
    if (_busy) return;
    setState(() => _busy = true);
    final wallet = context.read<StarWalletStore>();
    final rewarded = await AdsService.showRewardedForStars();
    if (!mounted) return;
    if (rewarded) {
      final gain = await wallet.awardRewardedAd();
      final quest = context.read<DailyQuestService>();
      await quest.markWatchAdDone();
      await quest.claimProgressRewards(wallet);
      if (mounted && gain > 0) {
        await StarEarnOverlay.show(
          context,
          amount: gain,
          newTotal: wallet.balance,
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final wallet = context.watch<StarWalletStore>();
    final cost = wallet.unlockCost(widget.id, widget.kind) ?? 0;
    final canAfford = wallet.balance >= cost;
    final adReward = wallet.economy?.rewardedAdReward ?? 5;
    final maxH = MediaQuery.sizeOf(context).height * 0.55;

    return AlertDialog(
      backgroundColor: StarBalancePill.fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: StarBalancePill.border.withValues(alpha: 0.95),
        ),
      ),
      title: Text(
        t.unlockWithStarsTitle,
        style: const TextStyle(
          color: StarBalancePill.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(StarBalancePill.asset, width: 36, height: 36),
                  const SizedBox(width: 8),
                  Text(
                    '$cost',
                    style: const TextStyle(
                      color: StarBalancePill.ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t.yourStars(wallet.balance),
                style: TextStyle(
                  color: StarBalancePill.ink.withValues(alpha: 0.85),
                ),
              ),
              if (!canAfford) ...[
                const SizedBox(height: 12),
                Text(
                  t.earnStarsSubtitle(adReward),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: StarBalancePill.ink.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _busy ? null : _watchAd,
                    customBorder: const CircleBorder(),
                    child: Opacity(
                      opacity: _busy ? 0.55 : 1,
                      child: Image.asset(
                        EarnStarsSheet.videoStarAsset,
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(
            t.cancel,
            style: const TextStyle(color: StarBalancePill.ink),
          ),
        ),
        FilledButton(
          onPressed: (!_busy && canAfford) ? _buy : null,
          style: FilledButton.styleFrom(
            backgroundColor: StarBalancePill.border,
            foregroundColor: StarBalancePill.ink,
            disabledBackgroundColor:
                StarBalancePill.border.withValues(alpha: 0.35),
            disabledForegroundColor:
                StarBalancePill.ink.withValues(alpha: 0.45),
          ),
          child: Text(t.unlock),
        ),
      ],
    );
  }
}
