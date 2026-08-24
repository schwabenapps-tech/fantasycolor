import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/coloring_page.dart';
import '../painting/coloring_bitmap.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/coloring_session.dart';
import '../widgets/coloring_canvas.dart';
import '../widgets/paint_side_rail.dart';
import '../widgets/silver_back_button.dart';

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
  bool _saveInFlight = false;
  Timer? _autoSaveTimer;
  late final AnimationController _celebrateController;

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
    if (_saveInFlight || !_session.canReset) return;
    _saveInFlight = true;
    try {
      final progress = context.read<ColoringProgressStore>();
      final png = flatten
          ? await _session.exportColoredPng()
          : await _session.renderColoredPng();
      if (png != null) {
        await progress.saveProgress(widget.page.id, png);
      }
    } finally {
      _saveInFlight = false;
    }
  }

  Future<void> _leaveScreen() async {
    _autoSaveTimer?.cancel();
    await _persistProgress(flatten: false);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    if (_celebrating) return;

    _autoSaveTimer?.cancel();
    await _persistProgress(flatten: true);

    if (!mounted) return;
    setState(() => _celebrating = true);
    await _celebrateController.forward(from: 0);
    if (!mounted) return;
    Navigator.of(context).pop();
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
            SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 52, 8, 16),
                            child: FutureBuilder<ColoringBitmap>(
                              future: _bitmapFuture,
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Bild konnte nicht geladen werden',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
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
                        ),
                        Positioned(
                          top: 8,
                          left: 12,
                          child: SilverBackButton(
                            onPressed: () => unawaited(_leaveScreen()),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 12,
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
                                  dimmed: !_session.canUndo &&
                                      !_session.canReset,
                                ),
                                const SizedBox(width: 10),
                                _DoneButton(onPressed: _finish),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                PaintSideRail(session: _session),
              ],
            ),
          ),
          if (_celebrating)
            _FinishCelebration(animation: _celebrateController),
        ],
      ),
      ),
    );
  }
}

class _FinishCelebration extends StatelessWidget {
  const _FinishCelebration({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
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
                final x = (math.sin(seed) * 0.5 + 0.5);
                final y = (0.15 + (t * (0.55 + (i % 5) * 0.08)))
                    .clamp(0.0, 1.0);
                final size = 6.0 + (i % 4) * 3.0;
                final colors = const [
                  Color(0xFFFFD56A),
                  Color(0xFFFF85A1),
                  Color(0xFFC9A6FF),
                  Color(0xFF6EE0FF),
                  Color(0xFFB6F5C8),
                ];
                return Positioned(
                  left: MediaQuery.sizeOf(context).width * x,
                  top: MediaQuery.sizeOf(context).height * y,
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
                        Text(
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
                        const SizedBox(height: 8),
                        Text(
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
