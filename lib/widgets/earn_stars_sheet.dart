import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/star_wallet_store.dart';
import '../services/ads_service.dart';

/// Großes Video-Stern-Overlay über dem Menü (statt Bottom-Sheet).
class EarnStarsSheet {
  EarnStarsSheet._();

  static const videoStarAsset = 'assets/images/videobelohnung.stern.png';

  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Earn stars',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => const _EarnStarsOverlay(),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _EarnStarsOverlay extends StatefulWidget {
  const _EarnStarsOverlay();

  @override
  State<_EarnStarsOverlay> createState() => _EarnStarsOverlayState();
}

class _EarnStarsOverlayState extends State<_EarnStarsOverlay> {
  bool _busy = false;

  Future<void> _watchAd() async {
    if (_busy) return;
    setState(() => _busy = true);
    final rewarded = await AdsService.showRewardedForStars();
    if (!mounted) return;
    if (rewarded) {
      final gain = await context.read<StarWalletStore>().awardRewardedAd();
      if (mounted && gain > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('+$gain')),
        );
      }
    }
    if (mounted) {
      setState(() => _busy = false);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final wallet = context.watch<StarWalletStore>();
    final reward = wallet.economy?.rewardedAdReward ?? 5;
    final size = MediaQuery.sizeOf(context);
    final buttonSize = (size.shortestSide * 0.62).clamp(220.0, 340.0);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            // Tippen außerhalb schließt.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox.expand(),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: () {}, // nicht durchreichen
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.earnStarsSubtitle(reward),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFFFF4C8),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _busy ? null : _watchAd,
                        customBorder: const CircleBorder(),
                        child: Opacity(
                          opacity: _busy ? 0.55 : 1,
                          child: Image.asset(
                            EarnStarsSheet.videoStarAsset,
                            width: buttonSize,
                            height: buttonSize,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
