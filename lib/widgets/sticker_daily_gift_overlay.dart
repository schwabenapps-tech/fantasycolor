import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/sticker_catalog.dart';
import '../providers/sticker_collection_store.dart';
import '../services/analytics_service.dart';
import 'sticker_reveal_overlay.dart';

/// 3-Boxen-Auswahl: geschlossene Box → Wackeln → Explosion → Sticker-Reveal.
///
/// Jede Box enthält einen **anderen** Sticker aus [choices] (oder Daily-Pool).
class StickerDailyGiftOverlay extends StatefulWidget {
  const StickerDailyGiftOverlay({
    super.key,
    required this.onClosed,
    this.choices,
    this.award,
    this.isDaily = false,
    this.title = 'Daily surprise!',
    this.subtitle = 'Pick a box for today’s reward',
    this.revealTitle = 'Daily reward!',
    this.source = 'daily',
  });

  final VoidCallback onClosed;

  /// Bis zu 3 verschiedene Sticker — eine Box pro Eintrag.
  final List<StickerEntry>? choices;

  /// Legacy: einzelne Zeremonie (wird zu einer 1-Box-Auswahl).
  final StickerEntry? award;

  /// Daily: Claim markiert den Tag und unlocked die gewählte Box.
  final bool isDaily;
  final String title;
  final String subtitle;
  final String revealTitle;
  final String source;

  static const closedBox = 'assets/images/geschenkbox_geschlossen.png';

  @override
  State<StickerDailyGiftOverlay> createState() =>
      _StickerDailyGiftOverlayState();
}

enum _GiftPhase { pick, shake, explode, reveal }

class _StickerDailyGiftOverlayState extends State<StickerDailyGiftOverlay>
    with TickerProviderStateMixin {
  int? _pickedIndex;
  StickerEntry? _won;
  _GiftPhase _phase = _GiftPhase.pick;
  List<StickerEntry> _choices = const [];

  late final AnimationController _intro;
  late final AnimationController _shake;
  late final AnimationController _burst;
  late final AnimationController _confetti;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
    );
    unawaited(_intro.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareChoices());
  }

  void _prepareChoices() {
    if (!mounted) return;
    final provided = widget.choices;
    if (provided != null && provided.isNotEmpty) {
      setState(() => _choices = provided.take(3).toList(growable: false));
      return;
    }
    if (widget.award != null) {
      setState(() => _choices = [widget.award!]);
      return;
    }
    final store = context.read<StickerCollectionStore>();
    final offered = store.offerChoices();
    if (offered.isEmpty) {
      widget.onClosed();
      return;
    }
    setState(() => _choices = offered);
  }

  @override
  void dispose() {
    _intro.dispose();
    _shake.dispose();
    _burst.dispose();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _pick(int index) async {
    if (_phase != _GiftPhase.pick) return;
    if (index < 0 || index >= _choices.length) return;
    setState(() {
      _pickedIndex = index;
      _phase = _GiftPhase.shake;
    });
    HapticFeedback.mediumImpact();
    await _shake.forward(from: 0);
    if (!mounted) return;

    setState(() => _phase = _GiftPhase.explode);
    HapticFeedback.heavyImpact();
    unawaited(_confetti.forward(from: 0));
    await _burst.forward(from: 0);
    if (!mounted) return;

    final chosen = _choices[index];
    final store = context.read<StickerCollectionStore>();
    StickerEntry? won;
    final daily = widget.isDaily ||
        (widget.choices == null && widget.award == null);
    if (daily) {
      won = await store.claimDailyChoice(chosen.id);
      if (!mounted) return;
      if (won == null) {
        widget.onClosed();
        return;
      }
      AnalyticsService.instance.logStickerUnlock(won.id, source: 'daily');
      AnalyticsService.instance.logDailyBoxClaim(won.id);
    } else {
      won = await store.unlock(chosen.id) ?? chosen;
      if (!mounted) return;
      AnalyticsService.instance.logStickerUnlock(won.id, source: widget.source);
    }
    if (!mounted) return;
    setState(() {
      _won = won;
      _phase = _GiftPhase.reveal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final won = _won;
    if (_phase == _GiftPhase.reveal && won != null) {
      return StickerRevealOverlay(
        sticker: won,
        title: widget.revealTitle,
        onDismiss: widget.onClosed,
      );
    }

    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final boxMax = landscape
        ? (size.height * 0.38).clamp(110.0, 168.0)
        : (size.width * 0.26).clamp(96.0, 140.0);

    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _shake, _burst, _confetti]),
      builder: (context, _) {
        return Material(
          color: Colors.black.withValues(alpha: 0.62 * _fade.value),
          child: Opacity(
            opacity: _fade.value,
            child: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_phase == _GiftPhase.explode ||
                      _phase == _GiftPhase.reveal)
                    IgnorePointer(
                      child: _BurstConfetti(
                        progress: _confetti.value,
                        intensity: _burst.value.clamp(0.0, 1.0),
                      ),
                    ),
                  Transform.scale(
                    scale: _scale.value,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: landscape ? 28 : 16,
                        vertical: landscape ? 12 : 20,
                      ),
                      child: Column(
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: landscape ? 22 : 24,
                              fontWeight: FontWeight.w800,
                              shadows: const [
                                Shadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: landscape ? 13 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: landscape ? 10 : 18),
                          Expanded(
                            child: Center(
                              child: _choices.isEmpty
                                  ? const SizedBox.shrink()
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (var i = 0;
                                              i < _choices.length;
                                              i++) ...[
                                            if (i > 0)
                                              SizedBox(
                                                width: landscape ? 18 : 12,
                                              ),
                                            SizedBox(
                                              width: boxMax,
                                              height: boxMax * 1.15,
                                              child: _GiftBox(
                                                selected: _pickedIndex == i,
                                                shaking: _phase ==
                                                        _GiftPhase.shake &&
                                                    _pickedIndex == i,
                                                shakeT: _shake.value,
                                                exploding: _phase ==
                                                        _GiftPhase.explode &&
                                                    _pickedIndex == i,
                                                burstT: _burst.value,
                                                dimmed: _pickedIndex != null &&
                                                    _pickedIndex != i,
                                                onTap: () =>
                                                    unawaited(_pick(i)),
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
                ],
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
    required this.selected,
    required this.shaking,
    required this.shakeT,
    required this.exploding,
    required this.burstT,
    required this.dimmed,
    required this.onTap,
  });

  final bool selected;
  final bool shaking;
  final double shakeT;
  final bool exploding;
  final double burstT;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Wackeln: Rotation + leichter X-Versatz.
    final shakeAngle = shaking
        ? math.sin(shakeT * math.pi * 10) * 0.14 * (1 - shakeT * 0.35)
        : 0.0;
    final shakeX = shaking
        ? math.sin(shakeT * math.pi * 8) * 7 * (1 - shakeT)
        : 0.0;

    // Explosion: Box wächst kurz und blendet aus.
    final burstScale = exploding ? 1.0 + Curves.easeOut.transform(burstT) * 0.85 : 1.0;
    final burstOpacity = exploding ? (1.0 - Curves.easeIn.transform(burstT)) : 1.0;

    Widget box = Image.asset(
      StickerDailyGiftOverlay.closedBox,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (exploding) {
      box = Stack(
        alignment: Alignment.center,
        children: [
          // Flash-Ring
          Opacity(
            opacity: (1 - burstT).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.6 + burstT * 2.2,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD56A)
                        .withValues(alpha: 0.85 * (1 - burstT)),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD56A)
                          .withValues(alpha: 0.45 * (1 - burstT)),
                      blurRadius: 28,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Opacity(
            opacity: burstOpacity,
            child: Transform.scale(scale: burstScale, child: box),
          ),
        ],
      );
    } else {
      box = Transform.translate(
        offset: Offset(shakeX, 0),
        child: Transform.rotate(
          angle: shakeAngle,
          child: AnimatedScale(
            scale: selected && !shaking ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 160),
            child: box,
          ),
        ),
      );
    }

    return Opacity(
      opacity: dimmed ? 0.28 : 1,
      child: GestureDetector(
        onTap: dimmed || shaking || exploding ? null : onTap,
        child: box,
      ),
    );
  }
}

/// Konfetti-Explosion vom Zentrum nach außen.
class _BurstConfetti extends StatelessWidget {
  const _BurstConfetti({
    required this.progress,
    required this.intensity,
  });

  final double progress;
  final double intensity;

  static const _colors = <Color>[
    Color(0xFFFFD56A),
    Color(0xFFFF85A1),
    Color(0xFFC9A6FF),
    Color(0xFF6EE0FF),
    Color(0xFFB6F5C8),
    Color(0xFFFFB347),
    Color(0xFFFF6B9D),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.shortestSide * 0.72;

    return Stack(
      children: [
        // Radial burst pieces
        ...List.generate(36, (i) {
          final angle = (i / 36) * math.pi * 2 + i * 0.11;
          final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
          final dist = maxR * t * (0.55 + (i % 5) * 0.1);
          final x = cx + math.cos(angle) * dist;
          final y = cy + math.sin(angle) * dist;
          final piece = 6.0 + (i % 4) * 2.2;
          final spin = progress * (6 + i % 4) + angle;
          final opacity =
              (intensity * (1.0 - progress * 0.85)).clamp(0.0, 1.0);

          return Positioned(
            left: x - piece / 2,
            top: y - piece / 2,
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: spin,
                child: i.isEven
                    ? Icon(
                        Icons.auto_awesome_rounded,
                        size: piece,
                        color: _colors[i % _colors.length],
                      )
                    : Container(
                        width: piece * 0.7,
                        height: piece * 1.2,
                        decoration: BoxDecoration(
                          color: _colors[i % _colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
              ),
            ),
          );
        }),
        // Falling confetti rain after burst
        ...List.generate(28, (i) {
          final seed = i * 17.3;
          final x = ((math.sin(seed) * 0.5 + 0.5) + i * 0.03) % 1.0;
          final fall = ((progress * (0.7 + (i % 5) * 0.08)) + i * 0.04) % 1.2;
          final y = fall - 0.1;
          final piece = 5.0 + (i % 4) * 2.0;
          final opacity =
              (intensity * 0.75 * (1 - (fall - 0.7).clamp(0.0, 1.0)))
                  .clamp(0.0, 0.9);
          return Positioned(
            left: size.width * x,
            top: size.height * y,
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: progress * 5 + seed,
                child: Container(
                  width: piece * 0.65,
                  height: piece,
                  decoration: BoxDecoration(
                    color: _colors[i % _colors.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
