import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/favorites_store.dart';
import '../providers/star_wallet_store.dart';
import '../services/ads_service.dart';
import 'star_balance_pill.dart';

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
    final rewarded = await AdsService.showRewardedForStars();
    if (!mounted) return;
    if (rewarded) {
      await context.read<StarWalletStore>().awardRewardedAd();
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

    return AlertDialog(
      backgroundColor: const Color(0xFF1B2A40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        t.unlockWithStarsTitle,
        style: const TextStyle(
          color: Color(0xFFFFF4C8),
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
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
                  color: Color(0xFFFFD56A),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.yourStars(wallet.balance),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          if (!canAfford) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: _busy ? null : _watchAd,
              child: Text(t.watchAdForStars(adReward)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: (!_busy && canAfford) ? _buy : null,
          child: Text(t.unlock),
        ),
      ],
    );
  }
}
