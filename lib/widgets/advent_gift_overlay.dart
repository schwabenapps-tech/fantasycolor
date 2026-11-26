import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../data/puzzle_images_loader.dart';
import '../data/sticker_catalog.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../models/puzzle_settings.dart';
import '../painting/puzzle_etch_painter.dart';
import '../providers/favorites_store.dart';
import '../providers/star_wallet_store.dart';
import '../providers/sticker_collection_store.dart';
import '../services/advent_service.dart';
import '../services/analytics_service.dart';
import '../utils/image_source.dart';
import 'star_earn_overlay.dart';
import 'sticker_reveal_overlay.dart';

/// Advent: Weihnachtsbox(en) — Geschenk erst nach Antippen sichtbar.
class AdventGiftOverlay extends StatefulWidget {
  const AdventGiftOverlay({
    super.key,
    required this.day,
    required this.onFinished,
  });

  final int day;
  final void Function(List<AdventReward> rewards) onFinished;

  static const boxAsset = 'assets/images/christmas.box.png';

  @override
  State<AdventGiftOverlay> createState() => _AdventGiftOverlayState();
}

class _AdventGiftOverlayState extends State<AdventGiftOverlay>
    with TickerProviderStateMixin {
  List<_PlannedGift>? _gifts;
  final _opened = <int>{};
  final _rewards = <AdventReward>[];
  int? _shaking;
  bool _revealing = false;
  bool _finishing = false;
  StickerEntry? _revealSticker;
  ColoringPage? _revealPage;
  String? _revealTitle;
  String? _revealSubtitle;
  bool _revealIsPuzzle = false;

  late final AnimationController _shake;
  late final AnimationController _intro;
  late final AnimationController _boxBurst;
  late final AnimationController _exit;
  bool _showBoxBurst = false;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _boxBurst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_prepare()));
  }

  Future<void> _prepare() async {
    // Nur explizite IDs aus advent_2026.json — kein Zufall aus dem normalen Katalog.
    final types = AdventService.rewardTypesForDay(widget.day);
    final cfg = AdventService.instance.doorConfig(widget.day);
    final stickers = context.read<StickerCollectionStore>();
    await stickers.load();

    final coloring = await loadColoringPages(shuffle: false);
    final puzzles = await loadPuzzleImages(shuffle: false);

    final gifts = <_PlannedGift>[];
    for (final type in types) {
      switch (type) {
        case AdventRewardType.sticker:
          final id = cfg.stickerId;
          if (id == null || id.isEmpty) continue;
          final pick = stickers.catalog?.byId(id);
          if (pick != null) gifts.add(_PlannedGift.sticker(pick));
        case AdventRewardType.coloring:
          final id = cfg.coloringId;
          if (id == null || id.isEmpty) continue;
          gifts.add(_PlannedGift.content(
            type: AdventRewardType.coloring,
            id: id,
            page: _pageById(coloring, id),
          ));
        case AdventRewardType.puzzle:
          final id = cfg.puzzleId;
          if (id == null || id.isEmpty) continue;
          gifts.add(_PlannedGift.content(
            type: AdventRewardType.puzzle,
            id: id,
            page: _pageById(puzzles, id),
          ));
      }
    }

    if (!mounted) return;
    if (gifts.isEmpty) {
      // Noch keine Advent-Assets konfiguriert — optional nur Bonus-Sterne (z. B. Tag 25).
      unawaited(_finishWithoutBoxes());
      return;
    }
    setState(() => _gifts = gifts);
  }

  Future<void> _finishWithoutBoxes() async {
    _finishing = true;
    final bonus = AdventService.instance.bonusStarsFor(widget.day);
    if (bonus > 0 && mounted) {
      final wallet = context.read<StarWalletStore>();
      await wallet.addStars(bonus);
      if (mounted) {
        await StarEarnOverlay.show(
          context,
          amount: bonus,
          newTotal: wallet.balance,
        );
      }
    }
    if (!mounted) return;
    widget.onFinished(const []);
  }

  ColoringPage? _pageById(List<ColoringPage> pages, String id) {
    for (final p in pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  void dispose() {
    _shake.dispose();
    _intro.dispose();
    _boxBurst.dispose();
    _exit.dispose();
    super.dispose();
  }

  Future<void> _pick(int index) async {
    if (_revealing || _finishing) return;
    final gifts = _gifts;
    if (gifts == null || index < 0 || index >= gifts.length) return;
    if (_opened.contains(index)) return;

    setState(() => _shaking = index);
    HapticFeedback.mediumImpact();

    // Unlock parallel zum Shake — weniger Wartezeit bis Reveal.
    final unlockFuture = _resolveGift(gifts[index]);
    await _shake.forward(from: 0);
    if (!mounted) return;

    setState(() => _showBoxBurst = true);
    HapticFeedback.heavyImpact();
    unawaited(_boxBurst.forward(from: 0));

    final resolved = await unlockFuture;
    // Burst kurz mitlaufen lassen, dann soft in Reveal.
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted || resolved == null) return;

    _rewards.add(resolved.reward);
    _opened.add(index);
    AnalyticsService.instance.logAdventDoorOpen(widget.day, resolved.reward.id);

    setState(() {
      _shaking = null;
      _showBoxBurst = false;
      _revealing = true;
      _revealSticker = resolved.sticker;
      _revealPage = resolved.page;
      _revealTitle = resolved.title;
      _revealSubtitle = null;
      _revealIsPuzzle = resolved.reward.type == AdventRewardType.puzzle;
    });
  }

  Future<({
    AdventReward reward,
    StickerEntry? sticker,
    ColoringPage? page,
    String title,
  })?> _resolveGift(_PlannedGift gift) async {
    if (!mounted) return null;
    final stickers = context.read<StickerCollectionStore>();
    final wallet = context.read<StarWalletStore>();
    final t = AppStrings.of(context);

    switch (gift.type) {
      case AdventRewardType.sticker:
        final entry = gift.sticker!;
        final unlocked =
            await stickers.unlock(entry.id, forPaint: true) ?? entry;
        AnalyticsService.instance.logStickerUnlock(
          unlocked.id,
          source: 'advent_${widget.day}',
        );
        if (unlocked.id == AdventService.firstAdventStickerId) {
          await AdventService.instance.unlockFirstAdventPuzzle();
          await wallet.grantUnlock(
            AdventService.firstAdventPuzzleId,
            FavoriteKind.puzzle,
          );
        }
        return (
          reward: AdventReward(
            type: AdventRewardType.sticker,
            id: unlocked.id,
          ),
          sticker: unlocked,
          page: null,
          title: t.adventRewardSticker,
        );
      case AdventRewardType.coloring:
        await wallet.grantUnlock(gift.id!, FavoriteKind.coloring);
        return (
          reward: AdventReward(
            type: AdventRewardType.coloring,
            id: gift.id!,
          ),
          sticker: null,
          page: gift.page,
          title: t.adventRewardColoring,
        );
      case AdventRewardType.puzzle:
        await wallet.grantUnlock(gift.id!, FavoriteKind.puzzle);
        return (
          reward: AdventReward(
            type: AdventRewardType.puzzle,
            id: gift.id!,
          ),
          sticker: null,
          page: gift.page,
          title: t.adventRewardPuzzle,
        );
    }
  }

  Future<void> _continueAfterReveal() async {
    if (_finishing) return;
    final gifts = _gifts;
    final moreBoxes =
        gifts != null && _opened.length < gifts.length;

    if (moreBoxes) {
      setState(() {
        _revealing = false;
        _revealSticker = null;
        _revealPage = null;
        _revealTitle = null;
        _revealSubtitle = null;
        _revealIsPuzzle = false;
      });
      return;
    }

    _finishing = true;
    // Soft ausblenden, bevor Overlay vom Parent entfernt wird.
    await _exit.reverse();
    if (!mounted) return;

    final bonus = AdventService.instance.bonusStarsFor(widget.day);
    if (bonus > 0 && mounted) {
      final wallet = context.read<StarWalletStore>();
      await wallet.addStars(bonus);
      if (mounted) {
        await StarEarnOverlay.show(
          context,
          amount: bonus,
          newTotal: wallet.balance,
        );
      }
    }
    if (!mounted) return;
    widget.onFinished(List.of(_rewards));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final gifts = _gifts;

    Widget body;
    if (_revealing) {
      final sticker = _revealSticker;
      if (sticker != null) {
        body = StickerRevealOverlay(
          sticker: sticker,
          title: _revealTitle ?? t.adventRewardSticker,
          onDismiss: () => unawaited(_continueAfterReveal()),
        );
      } else {
        body = GiftContentReveal(
          title: _revealTitle ?? t.adventRewardColoring,
          subtitle: _revealSubtitle,
          page: _revealPage,
          isPuzzle: _revealIsPuzzle,
          onContinue: () => unawaited(_continueAfterReveal()),
        );
      }
    } else if (gifts == null) {
      body = Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: const Center(child: CircularProgressIndicator()),
      );
    } else {
      final size = MediaQuery.sizeOf(context);
      // Eine Box: deutlich größer; mehrere: kompakter.
      final boxMax = gifts.length == 1
          ? (size.shortestSide * 0.52).clamp(180.0, 280.0)
          : (size.shortestSide * 0.32).clamp(110.0, 170.0);
      final left = gifts.length - _opened.length;
      final hint = gifts.length >= 3
          ? t.adventOpenThreeBoxes
          : gifts.length == 2
              ? t.adventOpenTwoBoxes
              : t.adventTapBox;

      body = Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_showBoxBurst)
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _boxBurst,
                    builder: (context, _) => GiftConfettiRain(
                      progress: _boxBurst.value,
                      intensity: (1.0 - _boxBurst.value).clamp(0.35, 1.0),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      t.adventDoorTitle(widget.day),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (gifts.length > 1) ...[
                      const SizedBox(height: 8),
                      Text(
                        t.adventBoxesLeft(left),
                        style: TextStyle(
                          color: Colors.amber.shade200,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (var i = 0; i < gifts.length; i++)
                              _AdventBox(
                                size: boxMax,
                                opened: _opened.contains(i),
                                shaking: _shaking == i,
                                shake: _shake,
                                onTap: () => unawaited(_pick(i)),
                              ),
                          ],
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
    }

    return FadeTransition(
      opacity: _exit.drive(CurveTween(curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: _intro,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey<Object>(
              _revealing
                  ? 'reveal-${_revealSticker?.id ?? _revealPage?.id ?? _revealTitle}'
                  : 'boxes-${gifts?.length ?? 0}',
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _PlannedGift {
  _PlannedGift._({
    required this.type,
    this.sticker,
    this.id,
    this.page,
  });

  factory _PlannedGift.sticker(StickerEntry sticker) => _PlannedGift._(
        type: AdventRewardType.sticker,
        sticker: sticker,
        id: sticker.id,
      );

  factory _PlannedGift.content({
    required AdventRewardType type,
    required String id,
    ColoringPage? page,
  }) =>
      _PlannedGift._(type: type, id: id, page: page);

  final AdventRewardType type;
  final StickerEntry? sticker;
  final String? id;
  final ColoringPage? page;
}

/// Reveal für Ausmal-/Puzzle-Geschenke (Advent + Silvester).
class GiftContentReveal extends StatefulWidget {
  const GiftContentReveal({
    super.key,
    required this.title,
    required this.onContinue,
    this.subtitle,
    this.page,
    this.isPuzzle = false,
  });

  final String title;
  final String? subtitle;
  final ColoringPage? page;
  final bool isPuzzle;
  final VoidCallback onContinue;

  @override
  State<GiftContentReveal> createState() => _GiftContentRevealState();
}

class _GiftContentRevealState extends State<GiftContentReveal>
    with TickerProviderStateMixin {
  late final AnimationController _confetti;
  late final AnimationController _pop;
  late final AnimationController _etch;
  late final AnimationController _yay;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _popScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _pop, curve: Curves.easeOutCubic),
    );
    _etch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    _yay = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    unawaited(_runIntro());
  }

  Future<void> _runIntro() async {
    await _pop.forward();
    if (!mounted) return;
    if (widget.isPuzzle) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      await _etch.forward();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;
    await _yay.forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _pop.dispose();
    _etch.dispose();
    _yay.dispose();
    super.dispose();
  }

  ({double w, double h}) _imageBox(double maxSide, double aspect) {
    final ar = aspect <= 0 ? 1.0 : aspect;
    if (ar >= 1) {
      return (w: maxSide, h: maxSide / ar);
    }
    return (w: maxSide * ar, h: maxSide);
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.page?.assetPath;
    final hasImage = path != null && isLocalImageAvailable(path);
    final aspect = widget.page?.aspectRatio ?? 1.0;

    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, _) => GiftConfettiRain(
                  progress: _confetti.value,
                  intensity: 1,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final chromeH = 26.0 +
                    18.0 +
                    22.0 +
                    52.0 +
                    ((widget.subtitle != null &&
                            widget.subtitle!.isNotEmpty)
                        ? 26.0
                        : 0.0);
                final pad = 24.0;
                final availW = (constraints.maxWidth - pad * 2)
                    .clamp(120.0, constraints.maxWidth);
                final availH = (constraints.maxHeight - pad * 2 - chromeH)
                    .clamp(120.0, constraints.maxHeight);
                final landscape = constraints.maxWidth > constraints.maxHeight;
                final target = landscape
                    ? math.min(availW * 0.58, availH * 0.92)
                    : math.min(availW * 0.92, availH * 0.88);
                final imageSide = target.clamp(160.0, 480.0);
                final box = _imageBox(imageSide, aspect);

                return Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_pop, _etch, _yay]),
                    builder: (context, _) {
                      return Transform.scale(
                        scale: _popScale.value,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFFFD56A),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xAA000000),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.subtitle != null &&
                                  widget.subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  widget.subtitle!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (hasImage) ...[
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: box.w,
                                  height: box.h,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image(
                                        image: imageProviderFor(path),
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                      ),
                                      if (widget.isPuzzle)
                                        CustomPaint(
                                          painter: PuzzleEtchPainter(
                                            aspect: aspect,
                                            progress: Curves.easeInOutCubic
                                                .transform(_etch.value),
                                            seed: widget.page?.id.hashCode ??
                                                42,
                                            targetPieces: PuzzleDifficulty
                                                .medium42.targetPieces,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              Opacity(
                                opacity: _yay.value.clamp(0.0, 1.0),
                                child: IgnorePointer(
                                  ignoring: _yay.value < 0.95,
                                  child: GoldenYayButton(
                                    onPressed: widget.onContinue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
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
