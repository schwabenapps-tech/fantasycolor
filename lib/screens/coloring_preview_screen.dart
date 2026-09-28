import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/coloring_page.dart';
import '../painting/coloring_bitmap.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/coloring_session.dart';
import '../services/ads_service.dart';
import '../services/audio_service.dart';
import '../services/gallery_export.dart';
import '../widgets/coloring_canvas.dart';
import '../widgets/level_complete_overlay.dart';
import '../widgets/paint_bottom_bar.dart';
import '../widgets/silver_back_button.dart';
import 'puzzle_screen.dart';

/// Interaktiver Mal-Screen mit PNG-Flood-Fill, Zoom, Undo und Fertig.
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

    // Parallelaufrufe (Auto-Save + Zurück/Fertig) immer auf den letzten Stand bringen.
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
    // Nur wenn man ohne Fertig-Feier zurückgeht.
    if (!_celebrating) {
      await _showLeaveAdOnce();
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    if (_celebrating) return;

    _autoSaveTimer?.cancel();
    await _persistProgress(flatten: true);

    if (!mounted) return;
    final saved = await context
        .read<ColoringProgressStore>()
        .loadProgressBytes(widget.page.id);
    _finishedPng = saved ?? await _session.renderColoredPng();

    if (!mounted) return;
    // Bild kurz in Ruhe zeigen, dann Level-Complete einblenden.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() => _celebrating = true);
    unawaited(AudioService.instance.playLevelComplete());
  }

  Future<void> _saveToPhotos() async {
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
        const SnackBar(content: Text('In die Fotogalerie gespeichert!')),
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
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: PuzzleScreen(
              puzzle: widget.page,
              customImage: MemoryImage(bytes),
            ),
          );
        },
      ),
    );
  }

  Future<void> _resetAllColors() async {
    _session.resetAll();
    await context.read<ColoringProgressStore>().clearProgress(widget.page.id);
  }

  @override
  Widget build(BuildContext context) {
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
                                'Bild konnte nicht geladen werden',
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
                                AnimatedBuilder(
                                  animation: _session,
                                  builder: (context, _) {
                                    return Row(
                                      children: [
                                        _MagicToolButton(
                                          icon: Icons.replay_rounded,
                                          tooltip: 'Zurücknehmen',
                                          colors: const [
                                            Color(0xFFFFE8F0),
                                            Color(0xFFE8A0BF),
                                            Color(0xFFC56B9E),
                                          ],
                                          iconColor: const Color(0xFF4A2038),
                                          onPressed: _session.canUndo
                                              ? _session.undo
                                              : null,
                                          onLongPress: _session.canReset
                                              ? _resetAllColors
                                              : null,
                                          dimmed: !_session.canUndo &&
                                              !_session.canReset,
                                        ),
                                        const SizedBox(width: 10),
                                        _MagicToolButton(
                                          icon: Icons.download_rounded,
                                          tooltip: 'In Fotos speichern',
                                          colors: const [
                                            Color(0xFFE8F6FF),
                                            Color(0xFF9EC8FF),
                                            Color(0xFF5B8FD4),
                                          ],
                                          iconColor: const Color(0xFF1A3358),
                                          onPressed: () =>
                                              unawaited(_saveToPhotos()),
                                        ),
                                        const SizedBox(width: 10),
                                        _MagicToolButton(
                                          icon: Icons.check_rounded,
                                          tooltip: 'Fertig',
                                          colors: const [
                                            Color(0xFFB6F5C8),
                                            Color(0xFF3DDC84),
                                            Color(0xFF1FA855),
                                          ],
                                          iconColor: const Color(0xFF0E3B22),
                                          onPressed: _finish,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PaintBottomBar(session: _session),
              ],
            ),
            if (_celebrating)
              LevelCompleteOverlay(
                key: _levelKey,
                title: 'Wunderbar!',
                subtitle: 'Level geschafft',
                actions: [
                  LevelCompleteActionButton(
                    icon: Icons.download_rounded,
                    label: 'In Fotos',
                    onPressed: () => unawaited(_saveToPhotos()),
                  ),
                  LevelCompleteActionButton(
                    icon: Icons.extension_rounded,
                    label: 'Als Puzzle',
                    onPressed: () => unawaited(_playAsPuzzle()),
                  ),
                  LevelCompleteActionButton(
                    icon: Icons.check_rounded,
                    label: 'Fertig',
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

/// Weicher Fantasy-Tool-Button (Undo / Fertig) — kein System-Grau.
class _MagicToolButton extends StatelessWidget {
  const _MagicToolButton({
    required this.icon,
    required this.colors,
    required this.iconColor,
    required this.onPressed,
    this.onLongPress,
    this.dimmed = false,
    this.tooltip,
  });

  final IconData icon;
  final List<Color> colors;
  final Color iconColor;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool dimmed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPress,
          customBorder: const StadiumBorder(),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
