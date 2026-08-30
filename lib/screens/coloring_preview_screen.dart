import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/coloring_page.dart';
import '../painting/coloring_bitmap.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/coloring_session.dart';
import '../services/ads_service.dart';
import '../widgets/coloring_canvas.dart';
import '../widgets/paint_side_rail.dart';
import '../widgets/silver_back_button.dart';
import 'puzzle_screen.dart';

/// Interaktiver Mal-Screen mit PNG-Flood-Fill, Stift, Zoom, Undo und Fertig.
class ColoringPreviewScreen extends StatefulWidget {
  const ColoringPreviewScreen({super.key, required this.page});

  final ColoringPage page;

  static const _paperBackground = 'assets/images/ausmalhintergund.png';

  @override
  State<ColoringPreviewScreen> createState() => _ColoringPreviewScreenState();
}

class _ColoringPreviewScreenState extends State<ColoringPreviewScreen>
    with TickerProviderStateMixin {
  late final ColoringSession _session;
  Future<ColoringBitmap>? _bitmapFuture;
  bool _celebrating = false;
  bool _showFinishActions = false;
  bool _saveInFlight = false;
  bool _saveAgain = false;
  bool _wantFlatten = false;
  bool _exitAdShown = false;
  Timer? _autoSaveTimer;
  late final AnimationController _celebrateController;
  Uint8List? _finishedPng;

  @override
  void initState() {
    super.initState();
    _session = ColoringSession();
    _session.addListener(_scheduleAutoSave);
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
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
    if (saved != null && bitmap.applyWorkingPng(saved)) {
      _session.markLoadedProgress();
    }
    return bitmap;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _session.removeListener(_scheduleAutoSave);
    _celebrateController.dispose();
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

  Future<void> _showExitAdOnce() async {
    if (_exitAdShown) return;
    _exitAdShown = true;
    await AdsService.showInterstitial();
  }

  Future<void> _leaveScreen() async {
    _autoSaveTimer?.cancel();
    await _persistProgress(flatten: false);
    await _showExitAdOnce();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    if (_celebrating) return;

    _autoSaveTimer?.cancel();
    await _persistProgress(flatten: true);
    // Fertig-Haken: einmal Werbung, danach Feier — Malen selbst bleibt ad-frei.
    await _showExitAdOnce();

    if (!mounted) return;
    final saved = await context
        .read<ColoringProgressStore>()
        .loadProgressBytes(widget.page.id);
    _finishedPng = saved ?? await _session.renderColoredPng();

    if (!mounted) return;
    setState(() {
      _celebrating = true;
      _showFinishActions = false;
    });
    await _celebrateController.forward(from: 0);
    if (!mounted) return;
    setState(() => _showFinishActions = true);
  }

  Future<void> _closeAfterFinish() async {
    await _showExitAdOnce();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _playAsPuzzle() async {
    final bytes = _finishedPng;
    if (bytes == null) {
      await _closeAfterFinish();
      return;
    }
    await _showExitAdOnce();
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
            // Canvas wirklich fullscreen — Zoom darf den ganzen Screen füllen.
            Positioned.fill(
              child: FutureBuilder<ColoringBitmap>(
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
            ),
            // Steuerung + Palette über dem Bild.
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 12,
                    child: SilverBackButton(
                      onPressed: () => unawaited(_leaveScreen()),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: PaintSideRail.widthOf(context) + 12,
                    child: AnimatedBuilder(
                      animation: _session,
                      builder: (context, _) {
                        return Row(
                          children: [
                            _RoundIconButton(
                              icon: Icons.undo_rounded,
                              onPressed:
                                  _session.canUndo ? _session.undo : null,
                              onLongPress: _session.canReset
                                  ? _resetAllColors
                                  : null,
                              dimmed:
                                  !_session.canUndo && !_session.canReset,
                            ),
                            const SizedBox(width: 10),
                            _DoneButton(onPressed: _finish),
                          ],
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: PaintSideRail(session: _session),
                  ),
                ],
              ),
            ),
            if (_celebrating)
              _FinishCelebration(
                animation: _celebrateController,
                showActions: _showFinishActions,
                onDone: _closeAfterFinish,
                onPlayPuzzle: _playAsPuzzle,
              ),
          ],
        ),
      ),
    );
  }
}

class _FinishCelebration extends StatelessWidget {
  const _FinishCelebration({
    required this.animation,
    required this.showActions,
    required this.onDone,
    required this.onPlayPuzzle,
  });

  final Animation<double> animation;
  final bool showActions;
  final VoidCallback onDone;
  final VoidCallback onPlayPuzzle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.35 * t.clamp(0, 1)),
            ),
            ...List.generate(28, (i) {
              final seed = i * 37.0;
              final x = math.sin(seed) * 0.5 + 0.5;
              final y = (0.15 + (t * (0.55 + (i % 5) * 0.08))).clamp(0.0, 1.0);
              final size = 6.0 + (i % 4) * 3.0;
              const colors = [
                Color(0xFFFFD56A),
                Color(0xFFFF85A1),
                Color(0xFFC9A6FF),
                Color(0xFF6EE0FF),
                Color(0xFFB6F5C8),
              ];
              return Positioned(
                left: MediaQuery.sizeOf(context).width * x,
                top: MediaQuery.sizeOf(context).height * y,
                child: IgnorePointer(
                  child: Opacity(
                    opacity:
                        (1.0 - (t - 0.15).clamp(0.0, 1.0)).clamp(0.2, 1.0),
                    child: Transform.rotate(
                      angle: t * 4 + i,
                      child: Icon(
                        i.isEven
                            ? Icons.auto_awesome_rounded
                            : Icons.star_rounded,
                        size: size,
                        color: colors[i % colors.length],
                      ),
                    ),
                  ),
                ),
              );
            }),
            Center(
              child: Opacity(
                opacity: Curves.easeOut.transform(t.clamp(0, 1)),
                child: Transform.scale(
                  scale: 0.85 +
                      0.2 * Curves.elasticOut.transform(t.clamp(0, 1)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IgnorePointer(
                        child: Text(
                          'Wunderbar!',
                          style: TextStyle(
                            color: const Color(0xFFFFD56A),
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: const Color(0xFFFFD56A)
                                    .withValues(alpha: 0.6),
                                blurRadius: 18,
                              ),
                              const Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      IgnorePointer(
                        child: Text(
                          'Dein Bild ist gespeichert',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showActions) ...[
                        const SizedBox(height: 22),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FinishActionButton(
                              icon: Icons.extension_rounded,
                              label: 'Als Puzzle',
                              filled: true,
                              onPressed: onPlayPuzzle,
                            ),
                            const SizedBox(width: 12),
                            _FinishActionButton(
                              icon: Icons.check_rounded,
                              label: 'Fertig',
                              filled: false,
                              onPressed: onDone,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FinishActionButton extends StatelessWidget {
  const _FinishActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: filled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF0C2),
                      Color(0xFFFFD56A),
                      Color(0xFFE0A93A),
                    ],
                  )
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: filled
                  ? const Color(0xFFFFE7A0)
                  : Colors.white.withValues(alpha: 0.35),
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD56A).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: filled
                    ? const Color(0xFF2A2410)
                    : Colors.white.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled
                      ? const Color(0xFF2A2410)
                      : Colors.white.withValues(alpha: 0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFB6F5C8),
                Color(0xFF3DDC84),
                Color(0xFF1FA855),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3DDC84).withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF0E3B22),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.dimmed = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPress,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7F9FC),
                  Color(0xFFC5CCD8),
                  Color(0xFF9AA3B5),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF243044), size: 24),
          ),
        ),
      ),
    );
  }
}
