import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/sticker_collection_store.dart';
import '../services/advent_service.dart';
import '../services/analytics_service.dart';
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

  AdventReward? _contentForDoor(int day) {
    final cfg = AdventService.instance.doorConfig(day);
    if (cfg.coloringId != null && cfg.coloringId!.isNotEmpty) {
      return AdventReward(
        type: AdventRewardType.coloring,
        id: cfg.coloringId!,
      );
    }
    if (cfg.puzzleId != null && cfg.puzzleId!.isNotEmpty) {
      return AdventReward(
        type: AdventRewardType.puzzle,
        id: cfg.puzzleId!,
      );
    }
    return null;
  }

  Future<void> _onGiftFinished(int day, List<AdventReward> rewards) async {
    await AdventService.instance.saveClaim(day, rewards);
    await StreakService.instance.recordPlayDay();
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
              pulls: advent.doorConfig(_activeDoor!).pulls,
              contentReward: _contentForDoor(_activeDoor!),
              onFinished: (rewards) =>
                  _onGiftFinished(_activeDoor!, rewards),
            ),
          if (_activeDoor != null && _reviewRewards != null)
            _ReviewSheet(
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

class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({
    required this.day,
    required this.rewards,
    required this.onClose,
  });

  final int day;
  final List<AdventReward> rewards;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final store = context.watch<StickerCollectionStore>();

    return Material(
      color: Colors.black54,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2A44),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.adventReviewTitle.replaceAll('{n}', '$day'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (rewards.isEmpty)
                  Text(
                    t.adventReviewEmpty,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final r in rewards) _rewardChip(store, r, t),
                    ],
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onClose,
                  child: Text(t.streakQuestClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rewardChip(
    StickerCollectionStore store,
    AdventReward r,
    AppStrings t,
  ) {
    if (r.type == AdventRewardType.sticker) {
      final entry = store.catalog?.byId(r.id);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: entry != null && isLocalImageAvailable(entry.assetPath)
                ? Image(
                    image: imageProviderFor(entry.assetPath),
                    fit: BoxFit.contain,
                  )
                : const Icon(Icons.sticky_note_2, color: Colors.white70),
          ),
          Text(
            t.adventRewardSticker,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      );
    }
    return Chip(
      label: Text(
        r.type == AdventRewardType.coloring
            ? t.adventRewardColoring
            : t.adventRewardPuzzle,
      ),
    );
  }
}
