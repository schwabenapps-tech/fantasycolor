import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/asset_dimensions.dart';
import '../data/sticker_catalog.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../providers/favorites_store.dart';
import '../providers/star_wallet_store.dart';
import '../providers/sticker_collection_store.dart';
import '../services/advent_service.dart';
import '../services/analytics_service.dart';
import '../services/remote_pack_service.dart';
import 'advent_gift_overlay.dart';
import 'sticker_reveal_overlay.dart';

/// Silvester 31.12.: Sticker + Feuerwerk-Puzzles + optionale Remote-Ausmalbilder.
class SilvesterGiftOverlay extends StatefulWidget {
  const SilvesterGiftOverlay({
    super.key,
    required this.onClosed,
  });

  final VoidCallback onClosed;

  static const boxAsset = 'assets/images/silvester.box.png';

  @override
  State<SilvesterGiftOverlay> createState() => _SilvesterGiftOverlayState();
}

enum _SilvesterPhase { pick, shake, explode, reveal }

enum _SilvesterGiftKind { sticker, puzzle, coloring }

class _SilvesterGift {
  const _SilvesterGift.sticker(this.sticker)
      : kind = _SilvesterGiftKind.sticker,
        contentId = null,
        page = null;

  const _SilvesterGift.puzzle({
    required String puzzleId,
    required this.page,
  })  : kind = _SilvesterGiftKind.puzzle,
        contentId = puzzleId,
        sticker = null;

  const _SilvesterGift.coloring({
    required String coloringId,
    required this.page,
  })  : kind = _SilvesterGiftKind.coloring,
        contentId = coloringId,
        sticker = null;

  final _SilvesterGiftKind kind;
  final StickerEntry? sticker;
  final String? contentId;
  final ColoringPage? page;
}

class _SilvesterGiftOverlayState extends State<SilvesterGiftOverlay>
    with TickerProviderStateMixin {
  _SilvesterPhase _phase = _SilvesterPhase.pick;
  List<_SilvesterGift>? _gifts;
  final Set<int> _opened = {};
  int? _shaking;
  bool _showBurst = false;
  bool _finishing = false;

  StickerEntry? _revealSticker;
  ColoringPage? _revealPage;
  String? _revealTitle;
  bool _revealIsPuzzle = false;

  late final AnimationController _intro;
  late final AnimationController _breath;
  late final AnimationController _ambient;
  late final AnimationController _shake;
  late final AnimationController _burst;
  late final AnimationController _exit;
  late final Animation<double> _scrim;
  late final Animation<double> _titleIn;
  late final Animation<double> _subIn;
  late final Animation<double> _boxesIn;

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
    )..repeat();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _exit = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 280),
    );
    _scrim = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
    );
    _titleIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.12, 0.42, curve: Curves.easeOutCubic),
    );
    _subIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.32, 0.58, curve: Curves.easeOutCubic),
    );
    _boxesIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.48, 1.0, curve: Curves.easeOutBack),
    );
    unawaited(
      _intro.forward().then((_) {
        if (!mounted || _phase != _SilvesterPhase.pick) return;
        unawaited(_breath.repeat(reverse: true));
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepare());
    });
  }

  Future<void> _prepare() async {
    if (!mounted) return;
    final stickers = context.read<StickerCollectionStore>();
    await stickers.load();

    // Remote-Pack syncen, damit Silvester-Ausmalbilder als Extra-Boxen da sind.
    try {
      await RemotePackService.instance.sync();
    } catch (_) {}

    // Direkt per Asset-Pfad laden — loadPuzzleImages filtert Silvester-Puzzles
    // bis revealSilvesterPack() aus dem Katalog.
    final dims = await AssetDimensionsManifest.load();
    ColoringPage pageFor(String id) =>
        dims.pageFromPath('assets/puzzle_images/$id.png');

    final remoteColorings =
        await RemotePackService.instance.silvesterGiftColoringPages();

    final sticker = stickers.catalog?.byId(AdventService.firstSilvesterStickerId) ??
        stickers.catalog?.byId('winter_silvester_sticker');
    final gifts = <_SilvesterGift>[
      if (sticker != null) _SilvesterGift.sticker(sticker),
      for (final id in AdventService.silvesterPuzzleIds)
        _SilvesterGift.puzzle(puzzleId: id, page: pageFor(id)),
      for (final page in remoteColorings)
        _SilvesterGift.coloring(coloringId: page.id, page: page),
    ];

    if (!mounted) return;
    if (gifts.isEmpty) {
      widget.onClosed();
      return;
    }
    setState(() => _gifts = gifts);
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    _ambient.dispose();
    _shake.dispose();
    _burst.dispose();
    _exit.dispose();
    super.dispose();
  }

  Future<void> _pick(int index) async {
    final gifts = _gifts;
    if (gifts == null || _phase != _SilvesterPhase.pick) return;
    if (_opened.contains(index) || _finishing) return;
    if (index < 0 || index >= gifts.length) return;

    _breath.stop();
    setState(() {
      _shaking = index;
      _phase = _SilvesterPhase.shake;
    });
    HapticFeedback.mediumImpact();
    await _shake.forward(from: 0);
    if (!mounted) return;

    setState(() {
      _phase = _SilvesterPhase.explode;
      _showBurst = true;
    });
    HapticFeedback.heavyImpact();
    unawaited(_burst.forward(from: 0));
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    final gift = gifts[index];
    final stickers = context.read<StickerCollectionStore>();
    final wallet = context.read<StarWalletStore>();
    final t = AppStrings.of(context);

    switch (gift.kind) {
      case _SilvesterGiftKind.puzzle:
        final id = gift.contentId!;
        await wallet.grantUnlock(id, FavoriteKind.puzzle);
        AnalyticsService.instance
            .logStickerUnlock(id, source: 'silvester_puzzle');
        setState(() {
          _opened.add(index);
          _shaking = null;
          _showBurst = false;
          _revealSticker = null;
          _revealPage = gift.page;
          _revealTitle = t.adventRewardPuzzle;
          _revealIsPuzzle = true;
          _phase = _SilvesterPhase.reveal;
        });
      case _SilvesterGiftKind.coloring:
        final id = gift.contentId!;
        await wallet.grantUnlock(id, FavoriteKind.coloring);
        AnalyticsService.instance
            .logStickerUnlock(id, source: 'silvester_coloring');
        setState(() {
          _opened.add(index);
          _shaking = null;
          _showBurst = false;
          _revealSticker = null;
          _revealPage = gift.page;
          _revealTitle = t.adventRewardColoring;
          _revealIsPuzzle = false;
          _phase = _SilvesterPhase.reveal;
        });
      case _SilvesterGiftKind.sticker:
        final entry = gift.sticker!;
        final unlocked =
            await stickers.unlock(entry.id, forPaint: true) ?? entry;
        AnalyticsService.instance.logStickerUnlock(
          unlocked.id,
          source: 'silvester_box',
        );
        // Zweiten Silvester-Sticker mit freischalten (Album).
        for (final id in AdventService.silvesterStickerIds) {
          if (id == unlocked.id) continue;
          await stickers.unlock(id, forPaint: true);
        }
        if (!mounted) return;
        setState(() {
          _opened.add(index);
          _shaking = null;
          _showBurst = false;
          _revealSticker = unlocked;
          _revealPage = null;
          _revealTitle = t.adventRewardSticker;
          _revealIsPuzzle = false;
          _phase = _SilvesterPhase.reveal;
        });
    }
  }

  Future<void> _continueAfterReveal() async {
    final gifts = _gifts;
    if (gifts != null && _opened.length < gifts.length) {
      setState(() {
        _phase = _SilvesterPhase.pick;
        _revealSticker = null;
        _revealPage = null;
        _revealTitle = null;
        _revealIsPuzzle = false;
      });
      if (!_breath.isAnimating) {
        unawaited(_breath.repeat(reverse: true));
      }
      if (!_ambient.isAnimating) {
        unawaited(_ambient.repeat());
      }
      return;
    }

    _finishing = true;
    _breath.stop();
    _ambient.stop();
    final stickers = context.read<StickerCollectionStore>();
    // Erst nach erfolgreicher Zeremonie verbrauchen — sonst bei App-Kill verloren.
    await stickers.consumeSilvesterGiftBox();
    await stickers.revealSilvesterPack();
    final wallet = context.read<StarWalletStore>();
    for (final id in AdventService.silvesterPuzzleIds) {
      await wallet.grantUnlock(id, FavoriteKind.puzzle);
    }
    for (final id in RemotePackService.instance.silvesterGiftColoringIds()) {
      await wallet.grantUnlock(id, FavoriteKind.coloring);
    }
    await _exit.reverse();
    if (!mounted) return;
    widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final gifts = _gifts;

    if (_phase == _SilvesterPhase.reveal) {
      final sticker = _revealSticker;
      if (sticker != null) {
        return StickerRevealOverlay(
          sticker: sticker,
          title: _revealTitle ?? t.adventRewardSticker,
          onDismiss: () => unawaited(_continueAfterReveal()),
        );
      }
      return GiftContentReveal(
        title: _revealTitle ??
            (_revealIsPuzzle ? t.adventRewardPuzzle : t.adventRewardColoring),
        page: _revealPage,
        isPuzzle: _revealIsPuzzle,
        onContinue: () => unawaited(_continueAfterReveal()),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge(
        [_intro, _breath, _ambient, _shake, _burst, _exit],
      ),
      builder: (context, _) {
        final titleT = _titleIn.value;
        final subT = _subIn.value;
        final boxesT = _boxesIn.value;
        final breathT = _phase == _SilvesterPhase.pick
            ? Curves.easeInOut.transform(_breath.value)
            : 0.0;
        final breathScale = 1.0 + breathT * 0.04;
        final breathY = -breathT * 6.0;
        final size = MediaQuery.sizeOf(context);
        final n = gifts?.length ?? 3;
        final boxMax = n <= 1
            ? (size.shortestSide * 0.62).clamp(220.0, 320.0)
            : n <= 3
                ? (size.shortestSide * 0.34).clamp(120.0, 168.0)
                : (size.shortestSide * 0.28).clamp(100.0, 140.0);
        final left = n - _opened.length;

        return FadeTransition(
          opacity: _exit.drive(CurveTween(curve: Curves.easeOut)),
          child: Material(
            color: Colors.black.withValues(alpha: 0.74 * _scrim.value),
            child: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: Opacity(
                      opacity: (0.4 + 0.6 * boxesT).clamp(0.0, 1.0),
                      child: GiftConfettiRain(
                        progress: _ambient.value,
                        intensity: 0.85,
                      ),
                    ),
                  ),
                  if (_showBurst)
                    IgnorePointer(
                      child: GiftConfettiRain(
                        progress: _burst.value,
                        intensity: (1.0 - _burst.value).clamp(0.4, 1.0),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      children: [
                        Opacity(
                          opacity: titleT,
                          child: Transform.translate(
                            offset: Offset(0, (1 - titleT) * 16),
                            child: Text(
                              'Silvester Surprise!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                shadows: [
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
                            offset: Offset(0, (1 - subT) * 12),
                            child: Text(
                              n <= 1
                                  ? t.adventTapBox
                                  : n == 2
                                      ? t.adventOpenTwoBoxes
                                      : n == 3
                                          ? t.adventOpenThreeBoxes
                                          : t.silvesterOpenBoxes(n),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (gifts != null && gifts.length > 1) ...[
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: subT,
                            child: Text(
                              t.adventBoxesLeft(left),
                              style: TextStyle(
                                color: Colors.amber.shade200,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: gifts == null
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : Opacity(
                                  opacity: boxesT.clamp(0.0, 1.0),
                                  child: Transform.scale(
                                    scale: 0.78 + 0.22 * boxesT,
                                    child: Transform.translate(
                                      offset: Offset(0, breathY),
                                      child: Transform.scale(
                                        scale: breathScale,
                                        child: Center(
                                          child: Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 14,
                                            runSpacing: 14,
                                            children: [
                                              for (var i = 0;
                                                  i < gifts.length;
                                                  i++)
                                                _SilvesterBox(
                                                  size: boxMax,
                                                  opened: _opened.contains(i),
                                                  shaking: _shaking == i,
                                                  shakeT: _shake.value,
                                                  exploding: _showBurst &&
                                                      _shaking == i,
                                                  burstT: _burst.value,
                                                  entrance: boxesT,
                                                  index: i,
                                                  onTap: () =>
                                                      unawaited(_pick(i)),
                                                ),
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
          ),
        );
      },
    );
  }
}

class _SilvesterBox extends StatelessWidget {
  const _SilvesterBox({
    required this.size,
    required this.opened,
    required this.shaking,
    required this.shakeT,
    required this.exploding,
    required this.burstT,
    required this.entrance,
    required this.index,
    required this.onTap,
  });

  final double size;
  final bool opened;
  final bool shaking;
  final double shakeT;
  final bool exploding;
  final double burstT;
  final double entrance;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.16).clamp(0.0, 0.5);
    final end = (start + 0.5).clamp(0.0, 1.0);
    final t = ((entrance - start) / (end - start)).clamp(0.0, 1.0);
    final curved = Curves.easeOutBack.transform(t);

    final shakeAngle = shaking
        ? math.sin(shakeT * math.pi * 10) * 0.14 * (1 - shakeT * 0.35)
        : 0.0;
    final shakeX = shaking
        ? math.sin(shakeT * math.pi * 8) * 7 * (1 - shakeT)
        : 0.0;
    final burstScale =
        exploding ? 1.0 + Curves.easeOut.transform(burstT) * 0.75 : 1.0;
    final burstOpacity =
        exploding ? (1.0 - Curves.easeIn.transform(burstT)) : 1.0;

    Widget box = Image.asset(
      SilvesterGiftOverlay.boxAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (opened) {
      box = Opacity(opacity: 0.22, child: box);
    } else if (exploding) {
      box = Opacity(
        opacity: burstOpacity,
        child: Transform.scale(scale: burstScale, child: box),
      );
    } else {
      box = Transform.translate(
        offset: Offset(shakeX, 0),
        child: Transform.rotate(angle: shakeAngle, child: box),
      );
    }

    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - curved) * 26),
        child: Transform.scale(
          scale: 0.8 + 0.2 * curved,
          child: SizedBox(
            width: size,
            height: size * 1.12,
            child: GestureDetector(
              onTap: opened || shaking || exploding ? null : onTap,
              child: box,
            ),
          ),
        ),
      ),
    );
  }
}
