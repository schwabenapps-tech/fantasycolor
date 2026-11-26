import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/sticker_catalog.dart';
import '../providers/star_wallet_store.dart';
import '../providers/sticker_collection_store.dart';
import '../providers/favorites_store.dart';
import '../services/advent_service.dart';
import '../services/analytics_service.dart';
import '../services/remote_pack_service.dart';
import 'silvester_gift_overlay.dart';
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
    this.forPaint = false,
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

  /// Auch im Ausmalen platzierbar freischalten.
  final bool forPaint;
  final String title;
  final String subtitle;
  final String revealTitle;
  final String source;

  static const closedBox = 'assets/images/geschenkbox_geschlossen.png';
  static const christmasBox = 'assets/images/christmas.box.png';
  static const silvesterBox = SilvesterGiftOverlay.boxAsset;

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
  String _boxAsset = StickerDailyGiftOverlay.closedBox;
  bool _silvesterGift = false;

  late final AnimationController _intro;
  late final AnimationController _breath;
  late final AnimationController _ambient;
  late final AnimationController _shake;
  late final AnimationController _burst;
  late final AnimationController _confetti;
  late final Animation<double> _scrim;
  late final Animation<double> _titleIn;
  late final Animation<double> _subtitleIn;
  late final Animation<double> _boxIn;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
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
    _scrim = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
    );
    _titleIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.12, 0.42, curve: Curves.easeOutCubic),
    );
    _subtitleIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.32, 0.58, curve: Curves.easeOutCubic),
    );
    _boxIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.48, 1.0, curve: Curves.easeOutBack),
    );
    // Funken schon während dem Intro leise anlaufen.
    unawaited(_ambient.repeat());
    unawaited(
      _intro.forward().then((_) {
        if (!mounted || _phase != _GiftPhase.pick) return;
        unawaited(_breath.repeat(reverse: true));
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepare());
    });
  }

  Future<void> _prepare() async {
    if (!mounted) return;
    final store = context.read<StickerCollectionStore>();
    await store.load();
    if (!mounted) return;

    // Box für dieses Overlay einfrieren: Silvester → eigenes 3-Boxen-Overlay.
    var box = StickerDailyGiftOverlay.closedBox;
    if (AdventService.usesChristmasGiftBox()) {
      box = StickerDailyGiftOverlay.christmasBox;
    } else if (store.canUseSilvesterGiftBox) {
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (ctx, _, _) => SilvesterGiftOverlay(
            onClosed: () {
              Navigator.of(ctx).pop();
              widget.onClosed();
            },
          ),
        ),
      );
      return;
    }

    List<StickerEntry> choices;
    final provided = widget.choices;
    if (provided != null && provided.isNotEmpty) {
      choices = provided.take(3).toList(growable: false);
    } else if (widget.award != null) {
      choices = [widget.award!];
    } else {
      final offered = store.offerChoices();
      if (offered.isEmpty) {
        widget.onClosed();
        return;
      }
      choices = offered;
    }

    if (!mounted) return;
    setState(() {
      _boxAsset = box;
      _choices = choices;
      _silvesterGift = false;
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    _ambient.dispose();
    _shake.dispose();
    _burst.dispose();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _pick(int index) async {
    if (_phase != _GiftPhase.pick) return;
    if (index < 0 || index >= _choices.length) return;
    _breath.stop();
    _ambient.stop();
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
      won = await store.unlock(chosen.id, forPaint: widget.forPaint) ?? chosen;
      if (!mounted) return;
      AnalyticsService.instance.logStickerUnlock(
        won.id,
        source: _silvesterGift ? 'silvester_box' : widget.source,
      );
    }
    if (_silvesterGift) {
      await store.revealSilvesterPack();
      if (mounted) {
        final wallet = context.read<StarWalletStore>();
        for (final id in AdventService.silvesterPuzzleIds) {
          await wallet.grantUnlock(id, FavoriteKind.puzzle);
        }
        for (final id
            in RemotePackService.instance.silvesterGiftColoringIds()) {
          await wallet.grantUnlock(id, FavoriteKind.coloring);
        }
      }
    }
    if (won.id == AdventService.firstAdventStickerId) {
      final wallet = context.read<StarWalletStore>();
      await AdventService.instance.unlockFirstAdventPuzzle();
      await wallet.grantUnlock(
        AdventService.firstAdventPuzzleId,
        FavoriteKind.puzzle,
      );
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
    final singleBox = _silvesterGift || _choices.length <= 1;
    // Silvester / Einzelbox: groß und dominant; 3er-Daily bleibt kompakt.
    final boxMax = singleBox
        ? (landscape
            ? (size.height * 0.58).clamp(200.0, 320.0)
            : (size.width * 0.72).clamp(220.0, 340.0))
        : (landscape
            ? (size.height * 0.38).clamp(110.0, 168.0)
            : (size.width * 0.26).clamp(96.0, 140.0));

    return AnimatedBuilder(
      animation: Listenable.merge(
        [_intro, _breath, _ambient, _shake, _burst, _confetti],
      ),
      builder: (context, _) {
        final titleT = _titleIn.value;
        final subT = _subtitleIn.value;
        final boxT = _boxIn.value;
        // Sanftes Atmen nur in der Wartephase (nach Intro).
        final breathT =
            _phase == _GiftPhase.pick ? Curves.easeInOut.transform(_breath.value) : 0.0;
        final breathScale = 1.0 + breathT * 0.045;
        final breathY = -breathT * 7.0;
        final waiting = _phase == _GiftPhase.pick || _phase == _GiftPhase.shake;
        return Material(
          color: Colors.black.withValues(alpha: 0.72 * _scrim.value),
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (waiting)
                  IgnorePointer(
                    child: Opacity(
                      opacity: (0.35 + 0.65 * boxT).clamp(0.0, 1.0),
                      child: _AmbientSparkRain(
                        progress: _ambient.value,
                        festive: _silvesterGift,
                      ),
                    ),
                  ),
                if (_phase == _GiftPhase.explode ||
                    _phase == _GiftPhase.reveal)
                  IgnorePointer(
                    child: _BurstConfetti(
                      progress: _confetti.value,
                      intensity: _burst.value.clamp(0.0, 1.0),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: landscape ? 28 : 20,
                    vertical: landscape ? 12 : 24,
                  ),
                  child: Column(
                    children: [
                      Opacity(
                        opacity: titleT,
                        child: Transform.translate(
                          offset: Offset(0, (1 - titleT) * 18),
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: landscape
                                  ? 24
                                  : (singleBox ? 28 : 24),
                              fontWeight: FontWeight.w800,
                              shadows: const [
                                Shadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: subT,
                        child: Transform.translate(
                          offset: Offset(0, (1 - subT) * 14),
                          child: Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: landscape ? 14 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: landscape ? 12 : 22),
                      Expanded(
                        child: Center(
                          child: _choices.isEmpty
                              ? const SizedBox.shrink()
                              : Opacity(
                                  opacity: boxT.clamp(0.0, 1.0),
                                  child: Transform.scale(
                                    scale: 0.72 + 0.28 * boxT,
                                    child: Transform.translate(
                                      offset: Offset(0, (1 - boxT) * 36),
                                      child: singleBox
                                          ? SizedBox(
                                              width: boxMax,
                                              height: boxMax * 1.12,
                                              child: Transform.translate(
                                                offset: Offset(0, breathY),
                                                child: Transform.scale(
                                                  scale: breathScale,
                                                  child: _GiftBox(
                                                    asset: _boxAsset,
                                                    selected:
                                                        _pickedIndex == 0,
                                                    shaking: _phase ==
                                                            _GiftPhase
                                                                .shake &&
                                                        _pickedIndex == 0,
                                                    shakeT: _shake.value,
                                                    exploding: _phase ==
                                                            _GiftPhase
                                                                .explode &&
                                                        _pickedIndex == 0,
                                                    burstT: _burst.value,
                                                    dimmed: false,
                                                    onTap: () =>
                                                        unawaited(_pick(0)),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  for (var i = 0;
                                                      i < _choices.length;
                                                      i++) ...[
                                                    if (i > 0)
                                                      SizedBox(
                                                        width: landscape
                                                            ? 18
                                                            : 12,
                                                      ),
                                                    _StaggeredBoxEntrance(
                                                      index: i,
                                                      progress: boxT,
                                                      child: Transform.translate(
                                                        offset: Offset(
                                                          0,
                                                          breathY,
                                                        ),
                                                        child: Transform.scale(
                                                          scale: breathScale,
                                                          child: SizedBox(
                                                            width: boxMax,
                                                            height:
                                                                boxMax * 1.15,
                                                            child: _GiftBox(
                                                              asset: _boxAsset,
                                                              selected:
                                                                  _pickedIndex ==
                                                                      i,
                                                              shaking: _phase ==
                                                                      _GiftPhase
                                                                          .shake &&
                                                                  _pickedIndex ==
                                                                      i,
                                                              shakeT: _shake
                                                                  .value,
                                                              exploding: _phase ==
                                                                      _GiftPhase
                                                                          .explode &&
                                                                  _pickedIndex ==
                                                                      i,
                                                              burstT: _burst
                                                                  .value,
                                                              dimmed: _pickedIndex !=
                                                                      null &&
                                                                  _pickedIndex !=
                                                                      i,
                                                              onTap: () =>
                                                                  unawaited(
                                                                _pick(i),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 3er-Daily: Boxen nacheinander von links nach rechts.
class _StaggeredBoxEntrance extends StatelessWidget {
  const _StaggeredBoxEntrance({
    required this.index,
    required this.progress,
    required this.child,
  });

  final int index;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.18).clamp(0.0, 0.55);
    final end = (start + 0.45).clamp(0.0, 1.0);
    final t = ((progress - start) / (end - start)).clamp(0.0, 1.0);
    final curved = Curves.easeOutBack.transform(t);
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - curved) * 28),
        child: Transform.scale(
          scale: 0.78 + 0.22 * curved,
          child: child,
        ),
      ),
    );
  }
}

class _GiftBox extends StatelessWidget {
  const _GiftBox({
    required this.asset,
    required this.selected,
    required this.shaking,
    required this.shakeT,
    required this.exploding,
    required this.burstT,
    required this.dimmed,
    required this.onTap,
  });

  final String asset;
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
      asset,
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

/// Dauerregen aus Funken/Konfetti hinter der Box (Wartephase).
class _AmbientSparkRain extends StatelessWidget {
  const _AmbientSparkRain({
    required this.progress,
    this.festive = false,
  });

  final double progress;
  final bool festive;

  static const _colors = <Color>[
    Color(0xFFFFD56A),
    Color(0xFFFF85A1),
    Color(0xFFC9A6FF),
    Color(0xFF6EE0FF),
    Color(0xFFFFB347),
    Color(0xFFFF6B9D),
    Color(0xFFE8F0FF),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final count = festive ? 42 : 28;
    return Stack(
      children: [
        ...List.generate(count, (i) {
          final seed = i * 19.7 + (festive ? 3.1 : 0);
          final x = (math.sin(seed * 1.3) * 0.5 + 0.5 + i * 0.037) % 1.0;
          final speed = 0.55 + (i % 7) * 0.08;
          final phase = (progress * speed + (i * 0.061)) % 1.0;
          final y = phase;
          final drift = math.sin(progress * math.pi * 2 + seed) * 10;
          final piece = festive
              ? (5.0 + (i % 5) * 2.2)
              : (4.0 + (i % 4) * 1.8);
          final twinkle =
              0.35 + 0.65 * (0.5 + 0.5 * math.sin(progress * math.pi * 4 + seed));
          final opacity = (0.55 * twinkle * (1.0 - (phase - 0.85).clamp(0.0, 1.0) / 0.15))
              .clamp(0.0, 0.9);
          final color = _colors[i % _colors.length];
          final isSpark = i % 3 != 0;

          return Positioned(
            left: size.width * x + drift - piece / 2,
            top: size.height * y - piece,
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: progress * (3 + i % 4) + seed,
                child: isSpark
                    ? Icon(
                        Icons.auto_awesome_rounded,
                        size: piece,
                        color: color,
                      )
                    : Container(
                        width: piece * 0.55,
                        height: piece * 1.15,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: festive
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.45),
                                    blurRadius: 6,
                                    spreadRadius: 0.5,
                                  ),
                                ]
                              : null,
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
