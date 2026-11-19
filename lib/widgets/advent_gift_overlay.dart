import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/sticker_catalog.dart';
import '../providers/sticker_collection_store.dart';
import '../services/advent_service.dart';
import '../services/analytics_service.dart';
import 'sticker_reveal_overlay.dart';

/// Advent: 3 Weihnachtsboxen, [pulls] mal ziehen (1/2/3).
class AdventGiftOverlay extends StatefulWidget {
  const AdventGiftOverlay({
    super.key,
    required this.day,
    required this.pulls,
    required this.onFinished,
    this.contentReward,
  });

  final int day;
  final int pulls;
  final AdventReward? contentReward;
  final void Function(List<AdventReward> rewards) onFinished;

  static const boxAsset = 'assets/images/christmas.box.png';

  @override
  State<AdventGiftOverlay> createState() => _AdventGiftOverlayState();
}

class _AdventGiftOverlayState extends State<AdventGiftOverlay>
    with TickerProviderStateMixin {
  late List<StickerEntry?> _boxStickers;
  final _opened = <int>{};
  final _rewards = <AdventReward>[];
  int _pullsLeft = 1;
  int? _shaking;
  bool _revealing = false;
  StickerEntry? _revealSticker;
  String? _revealNote;

  late final AnimationController _shake;
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _pullsLeft = widget.pulls.clamp(1, 3);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  void _prepare() {
    if (!mounted) return;
    final store = context.read<StickerCollectionStore>();
    final choices = store.offerChoices(count: 3);
    // Pad to 3 with nulls if pool thin.
    _boxStickers = [
      for (var i = 0; i < 3; i++)
        i < choices.length ? choices[i] : null,
    ];
    // Prefer putting content reward as "virtual" note on first unopened if needed.
    if (_boxStickers.every((e) => e == null) && widget.contentReward == null) {
      widget.onFinished(const []);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _shake.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _pick(int index) async {
    if (_revealing || _pullsLeft <= 0) return;
    if (_opened.contains(index)) return;
    setState(() => _shaking = index);
    HapticFeedback.mediumImpact();
    await _shake.forward(from: 0);
    if (!mounted) return;

    final store = context.read<StickerCollectionStore>();
    AdventReward? reward;
    StickerEntry? sticker = (index < _boxStickers.length)
        ? _boxStickers[index]
        : null;

    // Erster Pull an Sondertagen: optional Content statt Sticker, wenn gesetzt.
    if (widget.contentReward != null &&
        !_rewards.any((r) =>
            r.type == AdventRewardType.coloring ||
            r.type == AdventRewardType.puzzle)) {
      reward = widget.contentReward;
      _revealNote = reward!.type == AdventRewardType.coloring
          ? 'New coloring page!'
          : 'New puzzle!';
      _revealSticker = null;
    } else if (sticker != null) {
      final unlocked = await store.unlock(sticker.id);
      reward = AdventReward(
        type: AdventRewardType.sticker,
        id: (unlocked ?? sticker).id,
      );
      _revealSticker = unlocked ?? sticker;
      _revealNote = null;
      AnalyticsService.instance.logStickerUnlock(
        reward.id,
        source: 'advent_${widget.day}',
      );
    } else {
      // Fallback: irgend ein unowned.
      final pool = store.offerChoices(count: 1);
      if (pool.isNotEmpty) {
        final unlocked = await store.unlock(pool.first.id);
        reward = AdventReward(
          type: AdventRewardType.sticker,
          id: (unlocked ?? pool.first).id,
        );
        _revealSticker = unlocked ?? pool.first;
      }
    }

    if (reward != null) _rewards.add(reward);
    _opened.add(index);
    _pullsLeft -= 1;
    AnalyticsService.instance.logAdventDoorOpen(widget.day, reward?.id ?? '');

    if (!mounted) return;
    setState(() {
      _shaking = null;
      _revealing = true;
    });
  }

  void _continueAfterReveal() {
    setState(() {
      _revealing = false;
      _revealSticker = null;
      _revealNote = null;
    });
    if (_pullsLeft <= 0 || _opened.length >= 3) {
      widget.onFinished(List.of(_rewards));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_revealing) {
      final sticker = _revealSticker;
      if (sticker != null) {
        return StickerRevealOverlay(
          sticker: sticker,
          title: 'Advent gift!',
          onDismiss: _continueAfterReveal,
        );
      }
      return Material(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _revealNote ?? 'Unlocked!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _continueAfterReveal,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final boxMax = (size.shortestSide * 0.28).clamp(96.0, 150.0);

    return FadeTransition(
      opacity: _intro,
      child: Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Door ${widget.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _pullsLeft >= 3
                      ? 'Open all three gifts!'
                      : _pullsLeft == 2
                          ? 'Pick two boxes!'
                          : 'Pick a Christmas box!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_pullsLeft left',
                  style: TextStyle(
                    color: Colors.amber.shade200,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          _AdventBox(
                            size: boxMax,
                            opened: _opened.contains(i),
                            shaking: _shaking == i,
                            shake: _shake,
                            onTap: () => unawaited(_pick(i)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdventBox extends StatelessWidget {
  const _AdventBox({
    required this.size,
    required this.opened,
    required this.shaking,
    required this.shake,
    required this.onTap,
  });

  final double size;
  final bool opened;
  final bool shaking;
  final Animation<double> shake;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shake,
      builder: (context, child) {
        final t = shaking ? shake.value : 0.0;
        final dx = math.sin(t * math.pi * 8) * 6 * (1 - t);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: Opacity(
        opacity: opened ? 0.35 : 1,
        child: GestureDetector(
          onTap: opened ? null : onTap,
          child: SizedBox(
            width: size,
            height: size * 1.1,
            child: Image.asset(
              AdventGiftOverlay.boxAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
