import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../data/puzzle_images_loader.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../providers/sticker_collection_store.dart';
import '../providers/star_wallet_store.dart';
import '../services/advent_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_quest_service.dart';
import '../services/streak_service.dart';
import '../utils/app_layout.dart';
import '../utils/image_source.dart';
import '../widgets/advent_gift_overlay.dart';
import '../widgets/silver_back_button.dart';
import '../widgets/winter_atmosphere_overlay.dart';

/// 25 Weihnachtskugel-Türchen mit Öffnen / Rückblick.
class AdventCalendarScreen extends StatefulWidget {
  const AdventCalendarScreen({super.key});

  static const backgroundAsset = 'assets/images/winterhintergrund.png';

  @override
  State<AdventCalendarScreen> createState() => _AdventCalendarScreenState();
}

class _AdventCalendarScreenState extends State<AdventCalendarScreen> {
  int? _activeDoor;
  List<AdventReward>? _reviewRewards;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('advent_calendar');
    unawaited(() async {
      await AdventService.instance.load();
      if (mounted) setState(() {});
    }());
  }

  Future<void> _onDoorTap(int day) async {
    final advent = AdventService.instance;
    if (advent.isOpened(day)) {
      setState(() {
        _reviewRewards = advent.rewardsFor(day);
        _activeDoor = day;
      });
      return;
    }
    if (!advent.canOpen(day)) return;
    setState(() {
      _activeDoor = day;
      _reviewRewards = null;
    });
  }

  Future<void> _onGiftFinished(int day, List<AdventReward> rewards) async {
    await AdventService.instance.saveClaim(day, rewards);
    await StreakService.instance.recordPlayDay();
    if (mounted) {
      final quest = context.read<DailyQuestService>();
      final wallet = context.read<StarWalletStore>();
      await quest.markAdventDoorDone();
      await quest.claimProgressRewards(wallet);
    }
    if (!mounted) return;
    setState(() {
      _activeDoor = null;
      _reviewRewards = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final advent = context.watch<AdventService>();
    final layout = AppLayout.of(context);
    final landscape = layout.isLandscape;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AdventCalendarScreen.backgroundAsset,
            fit: BoxFit.cover,
          ),
          const WinterAtmosphereOverlay(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: Row(
                    children: [
                      SilverBackButton(onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.adventCalendar,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: landscape ? 24 : 12,
                      vertical: 8,
                    ),
                    child: GridView.builder(
                      key: const PageStorageKey<String>('advent_doors'),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: landscape ? 8 : 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: 25,
                      itemBuilder: (context, index) {
                        final day = index + 1;
                        return _DoorBauble(
                          day: day,
                          opened: advent.isOpened(day),
                          locked: advent.isLockedFuture(day),
                          canOpen: advent.canOpen(day),
                          onTap: () => _onDoorTap(day),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_activeDoor != null && _reviewRewards == null)
            AdventGiftOverlay(
              day: _activeDoor!,
              onFinished: (rewards) =>
                  unawaited(_onGiftFinished(_activeDoor!, rewards)),
            ),
          if (_activeDoor != null && _reviewRewards != null)
            AdventReviewOverlay(
              day: _activeDoor!,
              rewards: _reviewRewards!,
              onClose: () => setState(() {
                _activeDoor = null;
                _reviewRewards = null;
              }),
            ),
        ],
      ),
    );
  }
}

class _DoorBauble extends StatefulWidget {
  const _DoorBauble({
    required this.day,
    required this.opened,
    required this.locked,
    required this.canOpen,
    required this.onTap,
  });

  final int day;
  final bool opened;
  final bool locked;
  final bool canOpen;
  final VoidCallback onTap;

  static const _baubles = [
    'assets/images/advent_bauble_red.png',
    'assets/images/advent_bauble_gold.png',
    'assets/images/advent_bauble_green.png',
  ];

  @override
  State<_DoorBauble> createState() => _DoorBaubleState();
}

class _DoorBaubleState extends State<_DoorBauble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sway;

  @override
  void initState() {
    super.initState();
    // Leicht versetzt pro Tag → natürliches Schaukeln im Grid.
    // Alle Kugeln schaukeln (gesperrt, offen, freigegeben).
    final phase = (widget.day % 7) / 7.0;
    _sway = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2200 + (widget.day % 5) * 180),
    )..value = phase;
    unawaited(_sway.repeat(reverse: true));
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.canOpen || widget.opened;
    final asset = _DoorBauble._baubles[(widget.day - 1) % 3];
    final showLock = widget.locked && !widget.opened;

    return GestureDetector(
      onTap: interactive ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _sway,
        builder: (context, child) {
          final angle = math.sin(_sway.value * math.pi * 2) * 0.11;
          return Transform.rotate(
            angle: angle,
            alignment: const Alignment(0, -0.85),
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            // Etwas tiefer: optische Mitte der Kugel (unter dem Aufhänger).
            Transform.translate(
              offset: const Offset(0, 7),
              child: Text(
                widget.opened ? '✓' : '${widget.day}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: widget.opened ? 20 : 17,
                  shadows: const [
                    Shadow(blurRadius: 6, color: Colors.black87),
                    Shadow(blurRadius: 2, color: Colors.black54),
                  ],
                ),
              ),
            ),
            if (showLock)
              Positioned(
                right: 2,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 1),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Großes Vollbild-Overlay für bereits geöffnete Türchen (Hoch- + Querformat).
class AdventReviewOverlay extends StatefulWidget {
  const AdventReviewOverlay({
    super.key,
    required this.day,
    required this.rewards,
    required this.onClose,
  });

  final int day;
  final List<AdventReward> rewards;
  final VoidCallback onClose;

  @override
  State<AdventReviewOverlay> createState() => _AdventReviewOverlayState();
}

class _AdventReviewOverlayState extends State<AdventReviewOverlay> {
  Map<String, ColoringPage> _pagesById = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPages());
  }

  Future<void> _loadPages() async {
    final needsColoring = widget.rewards.any(
      (r) => r.type == AdventRewardType.coloring,
    );
    final needsPuzzle = widget.rewards.any(
      (r) => r.type == AdventRewardType.puzzle,
    );
    final map = <String, ColoringPage>{};
    if (needsColoring) {
      for (final p in await loadColoringPages(shuffle: false)) {
        map[p.id] = p;
      }
    }
    if (needsPuzzle) {
      for (final p in await loadPuzzleImages(shuffle: false)) {
        map[p.id] = p;
      }
    }
    if (!mounted) return;
    setState(() {
      _pagesById = map;
      _loading = false;
    });
  }

  String _labelFor(AdventReward r, AppStrings t) {
    return switch (r.type) {
      AdventRewardType.sticker => t.adventRewardSticker,
      AdventRewardType.coloring => t.adventRewardColoring,
      AdventRewardType.puzzle => t.adventRewardPuzzle,
    };
  }

  String? _assetPathFor(AdventReward r, StickerCollectionStore store) {
    if (r.type == AdventRewardType.sticker) {
      return store.catalog?.byId(r.id)?.assetPath;
    }
    return _pagesById[r.id]?.assetPath;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final store = context.watch<StickerCollectionStore>();
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: landscape ? 28 : 16,
            vertical: landscape ? 12 : 16,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.adventDoorTitle(widget.day),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: landscape ? 26 : 22,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(blurRadius: 10, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : widget.rewards.isEmpty
                        ? Center(
                            child: Text(
                              t.adventReviewEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 16,
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              const textReserve = 64.0;
                              final n = widget.rewards.length.clamp(1, 3);
                              final maxSide = landscape
                                  ? (constraints.maxHeight - textReserve)
                                      .clamp(120.0, 360.0)
                                  : math.min(
                                      (constraints.maxWidth / n) - 12,
                                      constraints.maxHeight - textReserve,
                                    ).clamp(120.0, 300.0);
                              return Center(
                                child: SingleChildScrollView(
                                  scrollDirection: landscape
                                      ? Axis.horizontal
                                      : Axis.vertical,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: Flex(
                                      direction: landscape
                                          ? Axis.horizontal
                                          : Axis.vertical,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        for (var i = 0;
                                            i < widget.rewards.length;
                                            i++) ...[
                                          if (i > 0)
                                            SizedBox(
                                              width: landscape ? 20 : 0,
                                              height: landscape ? 0 : 20,
                                            ),
                                          _ReviewGiftCard(
                                            maxSide: maxSide,
                                            maxHeight: constraints.maxHeight,
                                            label: _labelFor(
                                              widget.rewards[i],
                                              t,
                                            ),
                                            subtitle: widget.rewards[i]
                                                        .type ==
                                                    AdventRewardType.sticker
                                                ? null
                                                : _pagesById[
                                                        widget.rewards[i].id]
                                                    ?.title,
                                            assetPath: _assetPathFor(
                                              widget.rewards[i],
                                              store,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              TextButton(
                onPressed: widget.onClose,
                child: Text(
                  t.streakQuestClose,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewGiftCard extends StatelessWidget {
  const _ReviewGiftCard({
    required this.maxSide,
    required this.maxHeight,
    required this.label,
    required this.assetPath,
    this.subtitle,
  });

  final double maxSide;
  final double maxHeight;
  final String label;
  final String? subtitle;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        assetPath != null && isLocalImageAvailable(assetPath!);
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    final textBlock = 18.0 + (hasSubtitle ? 28.0 : 0) + 10.0;
    final side = math.min(maxSide, maxHeight - textBlock).clamp(96.0, maxSide);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFD56A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (hasSubtitle) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: side,
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: side,
          height: side,
          child: hasImage
              ? Image(
                  image: imageProviderFor(assetPath!),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                )
              : Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: side * 0.45,
                ),
        ),
      ],
    );
  }
}
