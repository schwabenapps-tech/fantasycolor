import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/paint_catalog.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../painting/colored_png_probe.dart';
import '../painting/coloring_bitmap.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/coloring_session.dart';
import '../providers/coloring_sticker_placements_store.dart';
import '../providers/favorites_store.dart';
import '../providers/feedback_survey_store.dart';
import '../providers/pixel_progress_store.dart';
import '../providers/pixel_ready_store.dart';
import '../providers/recent_content_store.dart';
import '../providers/star_wallet_store.dart';
import '../providers/sticker_collection_store.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/coloring_sticker_export.dart';
import '../services/daily_quest_service.dart';
import '../services/gallery_export.dart';
import '../services/streak_service.dart';
import '../utils/app_orientations.dart';
import '../utils/app_page_route.dart';
import '../widgets/coloring_canvas.dart';
import '../widgets/coloring_sticker_layer.dart';
import '../widgets/feedback_survey_overlay.dart';
import '../widgets/level_complete_overlay.dart';
import '../widgets/paint_bottom_bar.dart';
import '../widgets/silver_back_button.dart';
import 'puzzle_screen.dart';

/// Interaktiver Mal-Screen mit PNG-Flood-Fill, Zoom, Undo und Done.
class ColoringPreviewScreen extends StatefulWidget {
  const ColoringPreviewScreen({
    super.key,
    required this.page,
    this.recycleReset = false,
  });

  final ColoringPage page;

  /// Fertiges Bild: Farben ziehen sich zurück, dann saubere Vorlage.
  final bool recycleReset;

  static const _paperBackground = 'assets/images/ausmalhintergund.png';

  @override
  State<ColoringPreviewScreen> createState() => _ColoringPreviewScreenState();
}

class _ColoringPreviewScreenState extends State<ColoringPreviewScreen>
    with SingleTickerProviderStateMixin {
  late final ColoringSession _session;
  Future<ColoringBitmap>? _bitmapFuture;
  bool _celebrating = false;
  bool _saveInFlight = false;
  bool _saveAgain = false;
  bool _wantFlatten = false;
  bool _leaveAdShown = false;
  bool _finishChoiceAdShown = false;
  Timer? _autoSaveTimer;
  final _levelKey = GlobalKey<LevelCompleteOverlayState>();
  Uint8List? _finishedPng;
  int _earnedStars = 0;
  int _finishRating = 0;

  bool _recentRecorded = false;
  bool _recycleStarted = false;
  Uint8List? _recycleOverlayPng;
  late final AnimationController _recycleCtrl;

  @override
  void initState() {
    super.initState();
    unawaited(AppOrientations.enterPlay());
    _session = ColoringSession();
    _session.addListener(_scheduleAutoSave);
    _recycleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bitmapFuture ??= _loadBitmap();
    if (!_recentRecorded) {
      _recentRecorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          context.read<RecentContentStore>().record(
                widget.page.id,
                kind: FavoriteKind.coloring,
              ),
        );
      });
    }
  }

  Future<ColoringBitmap> _loadBitmap() async {
    final progress = context.read<ColoringProgressStore>();
    final bitmap = await ColoringBitmap.load(widget.page.assetPath);
    if (!mounted) return bitmap;
    final saved = await progress.loadProgressBytes(widget.page.id);
    if (saved != null) {
      if (await bitmap.applyWorkingPng(saved)) {
        _session.markLoadedProgress();
      } else {
        // Altes Motiv / andere Größe → Fortschritt verwerfen.
        await progress.clearProgress(widget.page.id);
      }
    }
    if (widget.recycleReset && !_recycleStarted) {
      _recycleStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runRecycleResetIfNeeded(bitmap));
      });
    }
    return bitmap;
  }

  Future<void> _runRecycleResetIfNeeded(ColoringBitmap bitmap) async {
    if (!widget.recycleReset) return;
    // Canvas hängt Bitmap erst in build — kurz warten.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    _session.attachBitmap(bitmap, notify: false);
    if (!_session.hasPaintedContent) {
      // Nichts zu recyceln — trotzdem Rewards/Placements säubern.
      await _clearRecyclePersistence();
      return;
    }
    final colored = await _session.renderColoredPng();
    if (!mounted || colored == null) {
      await _clearRecyclePersistence();
      _session.resetAll();
      return;
    }
    // Stickers sofort weg; Farben als Overlay zurückziehen.
    if (mounted) {
      await context
          .read<ColoringStickerPlacementsStore>()
          .setPlacements(widget.page.id, const []);
    }
    // Overlay zuerst voll sichtbar; Canvas darunter ausblenden.
    // Reset erst nach 2 Frames → kein Weiß-Blitz.
    setState(() => _recycleOverlayPng = colored);
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _session.resetAll();
    HapticFeedback.lightImpact();
    await _recycleCtrl.forward(from: 0);
    if (!mounted) return;
    await _clearRecyclePersistence();
    if (!mounted) return;
    setState(() => _recycleOverlayPng = null);
    HapticFeedback.selectionClick();
  }

  Future<void> _clearRecyclePersistence() async {
    if (!mounted) return;
    final progress = context.read<ColoringProgressStore>();
    final stickers = context.read<StickerCollectionStore>();
    final placements = context.read<ColoringStickerPlacementsStore>();
    final pixelReady = context.read<PixelReadyStore>();
    final pixelProgress = context.read<PixelProgressStore>();
    final wallet = context.read<StarWalletStore>();
    await progress.clearProgress(widget.page.id);
    await stickers.clearColoringRewarded(widget.page.id);
    await placements.setPlacements(widget.page.id, const []);
    await stickers.clearTempUnlocksForPage(widget.page.id);
    // Weiß nach Recycle → nicht weiter in Dot Art anbieten.
    await pixelReady.revokeReady(widget.page.id);
    await pixelProgress.clearProgress(widget.page.id);
    await wallet.clearColoringRating(widget.page.id);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _recycleCtrl.dispose();
    _session.removeListener(_scheduleAutoSave);
    _session.dispose();
    unawaited(AppOrientations.leavePlay());
    super.dispose();
  }

  void _scheduleAutoSave() {
    if (!_session.canReset) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_persistProgress(flatten: false));
    });
  }

  Future<void> _persistProgress({required bool flatten}) async {
    if (!_session.canReset) return;
    if (flatten) _wantFlatten = true;

    // Parallelaufrufe (Auto-Save + Back/Done) immer auf den letzten Stand bringen.
    if (_saveInFlight) {
      _saveAgain = true;
      while (_saveInFlight) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (!mounted || !_session.canReset) return;
    }

    _saveInFlight = true;
    try {
      do {
        _saveAgain = false;
        if (!mounted || !_session.canReset) break;
        final doFlatten = _wantFlatten;
        _wantFlatten = false;
        final progress = context.read<ColoringProgressStore>();
        final png = doFlatten
            ? await _session.exportColoredPng()
            : await _session.renderColoredPng();
        if (png != null) {
          await progress.saveProgress(widget.page.id, png);
        }
      } while (_saveAgain || _wantFlatten);
    } finally {
      _saveInFlight = false;
    }
  }

  Future<void> _showLeaveAdOnce() async {
    if (_leaveAdShown) return;
    _leaveAdShown = true;
    await AdsService.showColoringLeaveInterstitial();
  }

  Future<void> _showFinishChoiceAdOnce() async {
    if (_finishChoiceAdShown) return;
    _finishChoiceAdShown = true;
    await AdsService.showColoringFinishChoiceInterstitial();
  }

  void _undoFromTop(BuildContext context) {
    HapticFeedback.selectionClick();
    final stickers = context.read<ColoringStickerPlacementsStore>();
    final stickerUndo = stickers.canUndo(widget.page.id);
    final paintUndo = _session.canUndo;
    if (stickerUndo &&
        (!paintUndo ||
            stickers
                .lastChangeAt(widget.page.id)
                .isAfter(_session.lastChangeAt))) {
      unawaited(stickers.undo(widget.page.id));
      return;
    }
    if (paintUndo) {
      _session.undo();
    } else if (stickerUndo) {
      unawaited(stickers.undo(widget.page.id));
    }
  }

  Future<void> _leaveScreen() async {
    _autoSaveTimer?.cancel();
    await _persistProgress(flatten: false);
    // Nur wenn man ohne Done-Feier zurückgeht.
    if (!_celebrating) {
      await _showLeaveAdOnce();
    } else if (mounted) {
      // 3★-Zähler schon in _finish — Umfrage auch bei Back während der Feier.
      await FeedbackSurveyOverlay.maybeShowIfEligible(context);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onDonePressed() async {
    if (_celebrating) return;
    if (!_session.meetsStickerCoverage) {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).colorMoreForDone)),
      );
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_celebrating) return;
    // Done ab 1★ (~40 % Coverage).
    if (!_session.meetsStickerCoverage) return;

    _autoSaveTimer?.cancel();
    await _persistProgress(flatten: true);

    if (!mounted) return;
    final saved = await context
        .read<ColoringProgressStore>()
        .loadProgressBytes(widget.page.id);
    _finishedPng = saved ?? await _session.renderColoredPng();

    if (!mounted) return;
    final rating = _session.starRating;
    final wallet = context.read<StarWalletStore>();
    final quest = context.read<DailyQuestService>();
    final isDaily = quest.isTodaysQuestTarget(widget.page.id, coloring: true);
    var gained = 0;
    // Daily: Rating speichern (für Pixelart), aber keine Währungs-Sterne.
    if (isDaily) {
      await wallet.recordColoringRating(widget.page.id, rating);
    } else {
      gained = await wallet.awardColoringRating(widget.page.id, rating);
    }
    await quest.markColoringDone(widget.page.id, rating: rating);
    await quest.claimProgressRewards(wallet);

    if (!mounted) return;
    final stickers = context.read<StickerCollectionStore>();
    // Temp-Sticker-Freischaltungen enden mit Done (Besitz unverändert).
    await stickers.clearTempUnlocksForPage(widget.page.id);

    // Daily-fertig ODER 3★ / ~100 % → Pixelart-Galerie (wiederverwendbar).
    // Zusätzlich PNG-Probe: kein ready ohne echte Füllfarbe (Dot-Art-Gate).
    if (isDaily ||
        _session.starRating >= 3 ||
        _session.isFullyComplete) {
      final png = _finishedPng;
      if (png != null && await ColoredPngProbe.hasFillColors(png)) {
        if (!mounted) return;
        final pixelReady = context.read<PixelReadyStore>();
        await pixelReady.markReady(widget.page.id);
      }
    }
    if (_session.isFullyComplete) {
      if (!mounted) return;
      if (stickers.canRewardColoring(widget.page.id)) {
        await stickers.unlockForColoring(widget.page.id);
        await stickers.markColoringRewarded(widget.page.id);
      }
    }

    if (!mounted) return;
    // Umfrage-Zähler schon hier — unabhängig vom Exit-Pfad (Fertig / Back).
    if (rating >= 3) {
      await context.read<FeedbackSurveyStore>().recordColoringThreeStar();
    }
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() {
      _celebrating = true;
      // Flug-Sterne = Session-Rating; +N = Wallet (auch bei Wiederholung).
      _finishRating = rating.clamp(0, 3);
      _earnedStars = gained;
    });
    unawaited(AudioService.instance.playLevelComplete());
    unawaited(StreakService.instance.recordPlayDay());
    AnalyticsService.instance.logCompleteColoring(widget.page.id);
  }

  Future<void> _saveToPhotos() async {
    // Leere Vorlage nicht speichern — nur nach dem Ausmalen (oder nach Done).
    if (_finishedPng == null && !_session.hasPaintedContent) {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).colorBeforeSave)),
      );
      return;
    }
    try {
      var bytes = _finishedPng ?? await _session.renderColoredPng();
      if (bytes == null) return;
      if (!mounted) return;
      final placements =
          context.read<ColoringStickerPlacementsStore>().forPage(widget.page.id);
      if (placements.isNotEmpty) {
        final catalog = context.read<StickerCollectionStore>().catalog;
        bytes = await ColoringStickerExport.bake(
          basePng: bytes,
          placements: placements,
          assetPathFor: (id) => catalog?.byId(id)?.assetPath,
        );
      }
      await GalleryExport.savePngBytes(
        bytes,
        name: 'fantasy_color_${widget.page.id}',
      );
      AnalyticsService.instance.logShareColored(widget.page.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).savedToPhotos)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _closeAfterFinish() async {
    await _levelKey.currentState?.fadeOut();
    await _showFinishChoiceAdOnce();
    if (mounted) {
      await FeedbackSurveyOverlay.maybeShowIfEligible(context);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _playAsPuzzle() async {
    final bytes = _finishedPng;
    if (bytes == null) {
      await _closeAfterFinish();
      return;
    }
    await _levelKey.currentState?.fadeOut();
    await _showFinishChoiceAdOnce();
    if (mounted) {
      await FeedbackSurveyOverlay.maybeShowIfEligible(context);
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      AppPageRoute<void>(
        builder: (_) => PuzzleScreen(
          puzzle: widget.page,
          customImage: MemoryImage(bytes),
        ),
      ),
    );
  }

  Future<void> _resetAllColors() async {
    _session.resetAll();
    final progress = context.read<ColoringProgressStore>();
    final stickers = context.read<StickerCollectionStore>();
    final pixelReady = context.read<PixelReadyStore>();
    final pixelProgress = context.read<PixelProgressStore>();
    final wallet = context.read<StarWalletStore>();
    await progress.clearProgress(widget.page.id);
    // Nach Reset darf beim erneuten Fertigstellen wieder ein Sticker verdient werden.
    await stickers.clearColoringRewarded(widget.page.id);
    // Ausmalbild wieder weiß → Dot-Art-Freischaltung + Dot-Fortschritt weg.
    await pixelReady.revokeReady(widget.page.id);
    await pixelProgress.clearProgress(widget.page.id);
    // Stales Wallet-Rating sonst → syncFromCompletedColoring markiert wieder ready.
    await wallet.clearColoringRating(widget.page.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_leaveScreen());
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              ColoringPreviewScreen._paperBackground,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FutureBuilder<ColoringBitmap>(
                        future: _bitmapFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                t.couldNotLoadImage,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Color(0xFF8FA0C8),
                                ),
                              ),
                            );
                          }
                          final recycling = _recycleOverlayPng != null;
                          return AnimatedBuilder(
                            animation: _session,
                            builder: (context, _) {
                              return Opacity(
                                // Während Recycle unsichtbar → kein Blank-Blitz.
                                opacity: recycling ? 0 : 1,
                                child: ColoringStickerLayer(
                                  pageId: widget.page.id,
                                  editable: !_celebrating && !recycling,
                                  eraseMode:
                                      _session.tool == PaintTool.eraser,
                                  child: ColoringCanvas(
                                    bitmap: snapshot.data!,
                                    session: _session,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      if (_recycleOverlayPng != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              // Gleiche Papierfarbe wie Hintergrund — keine weißen Kanten.
                              color: const Color(0x00000000),
                              child: AnimatedBuilder(
                                animation: _recycleCtrl,
                                builder: (context, _) {
                                  final tAnim = Curves.easeInCubic
                                      .transform(_recycleCtrl.value);
                                  return Opacity(
                                    opacity: (1.0 - tAnim).clamp(0.0, 1.0),
                                    child: Image.memory(
                                      _recycleOverlayPng!,
                                      fit: BoxFit.contain,
                                      alignment: Alignment.center,
                                      filterQuality: FilterQuality.high,
                                      gaplessPlayback: true,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Builder(
                              builder: (context) {
                                final stickers = context
                                    .watch<ColoringStickerPlacementsStore>();
                                return AnimatedBuilder(
                                  animation: _session,
                                  builder: (context, _) {
                                    final canUndo = _session.canUndo ||
                                        stickers.canUndo(widget.page.id);
                                    final eraseOn =
                                        _session.tool == PaintTool.eraser;
                                    final pct =
                                        (_session.paintedCoverageRatio() * 100)
                                            .round()
                                            .clamp(0, 100);
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SilverBackButton(
                                          onPressed: () =>
                                              unawaited(_leaveScreen()),
                                        ),
                                        const Spacer(),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _TopToolChip(
                                              icon: Icons
                                                  .auto_fix_off_rounded,
                                              selected: eraseOn,
                                              onPressed: () {
                                                HapticFeedback
                                                    .selectionClick();
                                                _session.selectTool(
                                                  eraseOn
                                                      ? PaintTool.brush
                                                      : PaintTool.eraser,
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            _TopToolChip(
                                              icon: Icons.replay_rounded,
                                              enabled: canUndo,
                                              onPressed: () =>
                                                  _undoFromTop(context),
                                            ),
                                            const SizedBox(width: 8),
                                            _CoveragePill(percent: pct),
                                            const SizedBox(width: 10),
                                            _RoundActionButton(
                                              icon: Icons.download_rounded,
                                              tooltip: t.saveToPhotos,
                                              color: const Color(0xFF4A90E2),
                                              onPressed: () =>
                                                  unawaited(_saveToPhotos()),
                                            ),
                                            const SizedBox(width: 10),
                                            _RoundActionButton(
                                              icon: Icons.check_rounded,
                                              tooltip: t.done,
                                              color: const Color(0xFF2ECC71),
                                              onPressed: () =>
                                                  unawaited(_onDonePressed()),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PaintBottomBar(
                  session: _session,
                  pageId: widget.page.id,
                  onResetAll: () => unawaited(_resetAllColors()),
                ),
              ],
            ),
            if (_celebrating)
              LevelCompleteOverlay(
                key: _levelKey,
                title: t.wonderful,
                ratingStars: _finishRating,
                earnedStars: _earnedStars,
                fallbackSubtitle: t.levelComplete,
                actions: [
                  LevelCompleteActionButton(
                    icon: Icons.extension_rounded,
                    label: t.playColoredAsPuzzle,
                    prominent: true,
                    onPressed: () => unawaited(_playAsPuzzle()),
                  ),
                  LevelCompleteActionButton(
                    icon: Icons.download_rounded,
                    label: t.photos,
                    onPressed: () => unawaited(_saveToPhotos()),
                  ),
                  LevelCompleteActionButton(
                    icon: Icons.check_rounded,
                    label: t.done,
                    filled: false,
                    onPressed: () => unawaited(_closeAfterFinish()),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Runder Aktions-Button (Download / Done) — voll deckend, gleiches Look.
class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _TopToolChip extends StatelessWidget {
  const _TopToolChip({
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled || selected ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled || selected ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected
                  ? Colors.white.withValues(alpha: 0.92)
                  : Colors.black.withValues(alpha: 0.45),
              border: Border.all(
                color: selected
                    ? Colors.white
                    : const Color(0xFFFFD56A).withValues(alpha: 0.45),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: selected ? const Color(0xFF243044) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoveragePill extends StatelessWidget {
  const _CoveragePill({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(
          color: const Color(0xFFFFD56A).withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Text(
          '$percent %',
          style: const TextStyle(
            color: Color(0xFFFFE7A0),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
