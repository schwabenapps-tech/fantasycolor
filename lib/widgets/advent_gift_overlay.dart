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

  late final AnimationController _shake;
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
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
    super.dispose();
  }

  Future<void> _pick(int index) async {
    if (_revealing || _finishing) return;
    final gifts = _gifts;
    if (gifts == null || index < 0 || index >= gifts.length) return;
    if (_opened.contains(index)) return;

    setState(() => _shaking = index);
    HapticFeedback.mediumImpact();
    await _shake.forward(from: 0);
    if (!mounted) return;

    final gift = gifts[index];
    final stickers = context.read<StickerCollectionStore>();
    final wallet = context.read<StarWalletStore>();
    final t = AppStrings.of(context);

    AdventReward reward;
    StickerEntry? revealSticker;
    ColoringPage? revealPage;
    String? title;
    String? subtitle;

    switch (gift.type) {
      case AdventRewardType.sticker:
        final entry = gift.sticker!;
        final unlocked =
            await stickers.unlock(entry.id, forPaint: true) ?? entry;
        reward = AdventReward(type: AdventRewardType.sticker, id: unlocked.id);
        revealSticker = unlocked;
        title = t.adventRewardSticker;
        AnalyticsService.instance.logStickerUnlock(
          reward.id,
          source: 'advent_${widget.day}',
        );
      case AdventRewardType.coloring:
        reward = AdventReward(type: AdventRewardType.coloring, id: gift.id!);
        await wallet.grantUnlock(gift.id!, FavoriteKind.coloring);
        revealPage = gift.page;
        title = t.adventRewardColoring;
        subtitle = gift.page?.title;
      case AdventRewardType.puzzle:
        reward = AdventReward(type: AdventRewardType.puzzle, id: gift.id!);
        await wallet.grantUnlock(gift.id!, FavoriteKind.puzzle);
        revealPage = gift.page;
        title = t.adventRewardPuzzle;
        subtitle = gift.page?.title;
    }

    _rewards.add(reward);
    _opened.add(index);
    AnalyticsService.instance.logAdventDoorOpen(widget.day, reward.id);

    if (!mounted) return;
    setState(() {
      _shaking = null;
      _revealing = true;
      _revealSticker = revealSticker;
      _revealPage = revealPage;
      _revealTitle = title;
      _revealSubtitle = subtitle;
    });
  }

  Future<void> _continueAfterReveal() async {
    setState(() {
      _revealing = false;
      _revealSticker = null;
      _revealPage = null;
      _revealTitle = null;
      _revealSubtitle = null;
    });
    final gifts = _gifts;
    if (gifts == null) return;
    if (_opened.length < gifts.length) return;

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
    widget.onFinished(List.of(_rewards));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final gifts = _gifts;
    if (_revealing) {
      final sticker = _revealSticker;
      if (sticker != null) {
        return StickerRevealOverlay(
          sticker: sticker,
          title: _revealTitle ?? t.adventRewardSticker,
          onDismiss: () => unawaited(_continueAfterReveal()),
        );
      }
      return _ContentReveal(
        title: _revealTitle ?? t.adventRewardColoring,
        subtitle: _revealSubtitle,
        page: _revealPage,
        continueLabel: t.streakQuestClose,
        onContinue: () => unawaited(_continueAfterReveal()),
      );
    }

    if (gifts == null) {
      return Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final boxMax = (size.shortestSide * 0.32).clamp(110.0, 170.0);
    final left = gifts.length - _opened.length;
    final hint = gifts.length >= 3
        ? t.adventOpenThreeBoxes
        : gifts.length == 2
            ? t.adventOpenTwoBoxes
            : t.adventTapBox;

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

class _ContentReveal extends StatelessWidget {
  const _ContentReveal({
    required this.title,
    required this.onContinue,
    required this.continueLabel,
    this.subtitle,
    this.page,
  });

  final String title;
  final String? subtitle;
  final ColoringPage? page;
  final String continueLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final path = page?.assetPath;
    final hasImage = path != null && isLocalImageAvailable(path);
    return Material(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD56A),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (hasImage) ...[
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
                  child: Image(
                    image: imageProviderFor(path),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: onContinue,
                child: Text(continueLabel),
              ),
            ],
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
