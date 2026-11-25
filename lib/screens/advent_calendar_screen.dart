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
import '../widgets/sticker_reveal_overlay.dart';
import '../widgets/winter_atmosphere_overlay.dart';

/// 25 Weihnachtskugel-Türchen mit Öffnen / Rückblick.
class AdventCalendarScreen extends StatefulWidget {
  const AdventCalendarScreen({super.key});

  static const backgroundAsset = 'assets/images/winterhintergrund.png';
  static const titleBannerAsset =
      'assets/images/advent_merry_christmas_banner.png';

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
    final advent = context.watch<AdventService>();
    final layout = AppLayout.of(context);
    final landscape = layout.isLandscape;
    final today = advent.todayDoorDay;

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
                      const Spacer(),
                      _AdventProgressPill(
                        opened: advent.openedCount,
                        total: 25,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    landscape ? 40 : 10,
                    2,
                    landscape ? 40 : 10,
                    0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: landscape ? 96 : 132,
                    ),
                    child: Image.asset(
                      AdventCalendarScreen.titleBannerAsset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                // Kalender bewusst tiefer — Banner braucht Luft darunter.
                SizedBox(height: landscape ? 14 : 20),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      landscape ? 24 : 12,
                      0,
                      landscape ? 24 : 12,
                      12,
                    ),
                    child: GridView.builder(
                      key: const PageStorageKey<String>('advent_doors'),
                      clipBehavior: Clip.none,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: landscape ? 8 : 5,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: 25,
                      itemBuilder: (context, index) {
                        final day = index + 1;
                        return _DoorBauble(
                          day: day,
                          opened: advent.isOpened(day),
                          locked: advent.isLockedFuture(day),
                          canOpen: advent.canOpen(day),
                          isToday: today > 0 && day == today,
                          onTap: () => _onDoorTap(day),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _activeDoor == null
                ? const SizedBox.shrink(key: ValueKey('advent-none'))
                : _reviewRewards == null
                    ? AdventGiftOverlay(
                        key: ValueKey('advent-gift-$_activeDoor'),
                        day: _activeDoor!,
                        onFinished: (rewards) =>
                            unawaited(_onGiftFinished(_activeDoor!, rewards)),
                      )
                    : AdventReviewOverlay(
                        key: ValueKey('advent-review-$_activeDoor'),
                        day: _activeDoor!,
                        rewards: _reviewRewards!,
                        onClose: () => setState(() {
                          _activeDoor = null;
                          _reviewRewards = null;
                        }),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AdventProgressPill extends StatelessWidget {
  const _AdventProgressPill({
    required this.opened,
    required this.total,
  });

  final int opened;
  final int total;

  static const _bauble = 'assets/images/advent_bauble_gold.png';

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A44).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD56A).withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              _bauble,
              width: 26,
              height: 26,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: 6),
            Text(
              '$opened / $total',
              style: const TextStyle(
                color: Color(0xFFFFE7A0),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
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
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final bool opened;
  final bool locked;
  final bool canOpen;
  final bool isToday;
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
    with TickerProviderStateMixin {
  late final AnimationController _sway;
  late final AnimationController _pulse;

  bool get _todayHighlight =>
      widget.isToday && !widget.opened && widget.canOpen;

  bool get _shouldSway => !widget.opened;

  @override
  void initState() {
    super.initState();
    final phase = (widget.day % 7) / 7.0;
    _sway = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2200 + (widget.day % 5) * 180),
    )..value = phase;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant _DoorBauble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opened != widget.opened ||
        oldWidget.canOpen != widget.canOpen ||
        oldWidget.isToday != widget.isToday) {
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    if (_shouldSway) {
      if (!_sway.isAnimating) unawaited(_sway.repeat(reverse: true));
    } else {
      _sway.stop();
      _sway.value = 0;
    }
    if (_todayHighlight) {
      if (!_pulse.isAnimating) unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _sway.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.canOpen || widget.opened;
    final asset = _DoorBauble._baubles[(widget.day - 1) % 3];
    final showLock = widget.locked && !widget.opened;
    final dimmed = widget.opened;

    return GestureDetector(
      onTap: interactive ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_sway, _pulse]),
        builder: (context, _) {
          final angle = _shouldSway
              ? math.sin(_sway.value * math.pi * 2) * 0.11
              : 0.0;
          // Heute: sanftes Atmen + Glow (wie Home-Advent-Button), kein Kreis-Ring.
          final breath = _todayHighlight
              ? (0.5 + 0.5 * math.sin(_pulse.value * math.pi * 2))
              : 0.0;
          final scale = _todayHighlight ? 1.0 + 0.06 * breath : 1.0;
          final glow = _todayHighlight ? 0.45 + 0.5 * breath : 0.0;

          return Transform.rotate(
            angle: angle,
            alignment: const Alignment(0, -0.9),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: dimmed ? 0.55 : 1,
                child: CustomPaint(
                  painter: _BaubleStringPainter(
                    color: const Color(0xFFE8D5A3).withValues(alpha: 0.85),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (glow > 0)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD56A)
                                        .withValues(alpha: glow),
                                    blurRadius: 16 + 14 * breath,
                                    spreadRadius: 2 + 4 * breath,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFFFF4C8)
                                        .withValues(alpha: glow * 0.55),
                                    blurRadius: 8 + 6 * breath,
                                    spreadRadius: 1 + 2 * breath,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Image.asset(
                            asset,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                      // Optische Mitte der Kugel (unter dem Aufhänger).
                      Transform.translate(
                        offset: const Offset(0, 10),
                        child: Text(
                          widget.opened ? '✓' : '${widget.day}',
                          style: TextStyle(
                            color: widget.opened
                                ? const Color(0xFFFFE7A0)
                                : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: widget.opened ? 18 : 16,
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
                              border: Border.all(
                                color: Colors.white70,
                                width: 1,
                              ),
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
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dünne Aufhängeschnur von oben zur Kugel.
class _BaubleStringPainter extends CustomPainter {
  const _BaubleStringPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x = size.width / 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height * 0.14), paint);
  }

  @override
  bool shouldRepaint(covariant _BaubleStringPainter oldDelegate) =>
      oldDelegate.color != color;
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
                                            // Keine Dateinamen unter den Geschenken.
                                            subtitle: null,
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
              GoldenYayButton(onPressed: widget.onClose),
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
