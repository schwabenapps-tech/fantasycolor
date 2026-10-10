import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/sticker_catalog.dart';
import '../providers/sticker_collection_store.dart';
import '../services/analytics_service.dart';
import 'sticker_reveal_overlay.dart';

/// Tägliche 3-Boxen-Auswahl (Portrait + Landscape).
class StickerDailyGiftOverlay extends StatefulWidget {
  const StickerDailyGiftOverlay({
    super.key,
    required this.onClosed,
  });

  final VoidCallback onClosed;

  static const closedBox = 'assets/images/geschenkbox_geschlossen.png';
  static const openingBox = 'assets/images/geschenk_oeffnetsich.png';
  static const openBox = 'assets/images/geschenk_istoffen.png';

  @override
  State<StickerDailyGiftOverlay> createState() =>
      _StickerDailyGiftOverlayState();
}

class _StickerDailyGiftOverlayState extends State<StickerDailyGiftOverlay>
    with SingleTickerProviderStateMixin {
  int? _pickedIndex;
  bool _opening = false;
  StickerEntry? _won;
  late final AnimationController _intro;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
    );
    unawaited(_intro.forward());
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _pick(int index) async {
    if (_pickedIndex != null || _opening) return;
    setState(() {
      _pickedIndex = index;
      _opening = true;
    });
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    final store = context.read<StickerCollectionStore>();
    final won = await store.claimDailyRandom();
    if (!mounted) return;
    if (won == null) {
      widget.onClosed();
      return;
    }
    AnalyticsService.instance.logStickerUnlock(won.id, source: 'daily');
    AnalyticsService.instance.logDailyBoxClaim(won.id);
    setState(() {
      _opening = false;
      _won = won;
    });
  }

  @override
  Widget build(BuildContext context) {
    final won = _won;
    if (won != null) {
      return StickerRevealOverlay(
        sticker: won,
        title: 'Daily gift!',
        onDismiss: widget.onClosed,
      );
    }

    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final boxMax = landscape
        ? (size.height * 0.38).clamp(110.0, 168.0)
        : (size.width * 0.26).clamp(96.0, 140.0);

    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        return Material(
          color: Colors.black.withValues(alpha: 0.62 * _fade.value),
          child: Opacity(
            opacity: _fade.value,
            child: SafeArea(
              child: Transform.scale(
                scale: _scale.value,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: landscape ? 28 : 16,
                    vertical: landscape ? 12 : 20,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Pick a gift!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: landscape ? 22 : 24,
                          fontWeight: FontWeight.w800,
                          shadows: const [
                            Shadow(color: Color(0xAA000000), blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'One sticker is waiting for you',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: landscape ? 13 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: landscape ? 10 : 18),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < 3; i++) ...[
                                  if (i > 0) SizedBox(width: landscape ? 18 : 12),
                                  SizedBox(
                                    width: boxMax,
                                    height: boxMax * 1.15,
                                    child: _GiftBox(
                                      index: i,
                                      selected: _pickedIndex == i,
                                      opening: _opening && _pickedIndex == i,
                                      dimmed: _pickedIndex != null &&
                                          _pickedIndex != i,
                                      onTap: () => unawaited(_pick(i)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GiftBox extends StatelessWidget {
  const _GiftBox({
    required this.index,
    required this.selected,
    required this.opening,
    required this.dimmed,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final bool opening;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = opening
        ? StickerDailyGiftOverlay.openingBox
        : StickerDailyGiftOverlay.closedBox;
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: GestureDetector(
        onTap: dimmed || opening ? null : onTap,
        child: AnimatedScale(
          scale: selected ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
