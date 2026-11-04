import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/sticker_catalog.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../painting/coloring_bitmap.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/coloring_session.dart';
import '../providers/favorites_store.dart';
import '../providers/recent_content_store.dart';
import '../providers/sticker_collection_store.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/gallery_export.dart';
import '../services/streak_service.dart';
import '../utils/app_page_route.dart';
import '../widgets/coloring_canvas.dart';
import '../widgets/level_complete_overlay.dart';
import '../widgets/paint_bottom_bar.dart';
import '../widgets/silver_back_button.dart';
import '../widgets/sticker_daily_gift_overlay.dart';
import 'puzzle_screen.dart';

/// Interaktiver Mal-Screen mit PNG-Flood-Fill, Zoom, Undo und Done.
class ColoringPreviewScreen extends StatefulWidget {
  const ColoringPreviewScreen({super.key, required this.page});

  final ColoringPage page;

  static const _paperBackground = 'assets/images/ausmalhintergund.png';

  @override
  State<ColoringPreviewScreen> createState() => _ColoringPreviewScreenState();
}

class _ColoringPreviewScreenState extends State<ColoringPreviewScreen> {
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
  List<StickerEntry>? _giftChoices;

  bool _recentRecorded = false;

  @override
  void initState() {
    super.initState();
    _session = ColoringSession();
    _session.addListener(_scheduleAutoSave);
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
      if (bitmap.applyWorkingPng(saved)) {
        _session.markLoadedProgress();
      } else {
        // Altes Motiv / andere Größe → Fortschritt verwerfen.
        await progress.clearProgress(widget.page.id);
      }
    }
    return bitmap;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _session.removeListener(_scheduleAutoSave);
    _session.dispose();
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

  Future<void> _leaveScreen() async {
    _autoSaveTimer?.cancel();
    await _persistProgress(flatten: false);
    // Nur wenn man ohne Done-Feier zurückgeht.
    if (!_celebrating) {
      await _showLeaveAdOnce();
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
    // Done + Sticker nur ab 90 % Ausmal-Anteil.
    if (!_session.meetsStickerCoverage) return;

    _autoSaveTimer?.cancel();
    await _persistProgress(flatten: true);

    if (!mounted) return;
    final saved = await context
        .read<ColoringProgressStore>()
        .loadProgressBytes(widget.page.id);
    _finishedPng = saved ?? await _session.renderColoredPng();

    if (!mounted) return;
    final store = context.read<StickerCollectionStore>();
    await store.load();
    List<StickerEntry>? choices;
    if (store.canRewardColoring(widget.page.id)) {
      final offered = store.choicesForColoring(widget.page.id);
      if (offered.isNotEmpty) choices = offered;
    }

    if (!mounted) return;
    // Bild kurz in Ruhe zeigen, dann Sticker-Wahl / Level-Complete.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() {
      _celebrating = true;
      _giftChoices = choices;
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
      final bytes = _finishedPng ?? await _session.renderColoredPng();
      if (bytes == null) return;
      await GalleryExport.savePngBytes(
        bytes,
        name: 'fantasy_color_${widget.page.id}',
      );
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
    await context.read<ColoringProgressStore>().clearProgress(widget.page.id);
    // Nach Reset darf beim erneuten Fertigstellen wieder ein Sticker verdient werden.
    await context
        .read<StickerCollectionStore>()
        .clearColoringRewarded(widget.page.id);
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
                          return ColoringCanvas(
                            bitmap: snapshot.data!,
                            session: _session,
                          );
                        },
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SilverBackButton(
                                  onPressed: () => unawaited(_leaveScreen()),
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _RoundActionButton(
                                      icon: Icons.download_rounded,
                                      tooltip: t.saveToPhotos,
                                      color: const Color(0xFF4A90E2),
                                      onPressed: () =>
                                          unawaited(_saveToPhotos()),
                                    ),
                                    const SizedBox(width: 10),
                                    // Immer sichtbar; Fertigstellen erst ab 90 %.
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
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PaintBottomBar(
                  session: _session,
                  onResetAll: () => unawaited(_resetAllColors()),
                ),
              ],
            ),
            if (_celebrating && _giftChoices != null)
              StickerDailyGiftOverlay(
                choices: _giftChoices,
                source: 'coloring',
                title: t.pickAGift,
                subtitle: t.eachBoxDifferent,
                revealTitle: t.newSticker,
                onClosed: () {
                  unawaited(
                    context
                        .read<StickerCollectionStore>()
                        .markColoringRewarded(widget.page.id),
                  );
                  setState(() => _giftChoices = null);
                },
              ),
            if (_celebrating && _giftChoices == null)
              LevelCompleteOverlay(
                key: _levelKey,
                title: t.wonderful,
                subtitle: t.levelComplete,
                actions: [
                  LevelCompleteActionButton(
                    icon: Icons.download_rounded,
                    label: t.photos,
                    onPressed: () => unawaited(_saveToPhotos()),
                  ),
                  LevelCompleteActionButton(
                    icon: Icons.extension_rounded,
                    label: t.asPuzzle,
                    onPressed: () => unawaited(_playAsPuzzle()),
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
