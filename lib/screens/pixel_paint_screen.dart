import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';

import '../data/paint_catalog.dart';
import '../models/coloring_page.dart';
import '../models/pixel_puzzle.dart';
import '../painting/pixel_export.dart';
import '../painting/pixel_quantizer.dart';
import '../providers/pixel_progress_store.dart';
import '../services/ads_service.dart';
import '../widgets/pixel_paint_rail.dart';
import '../widgets/silver_back_button.dart';

/// Interaktives Malen-nach-Zahlen auf einem quantisierten Pixel-Raster.
class PixelPaintScreen extends StatefulWidget {
  const PixelPaintScreen({
    super.key,
    required this.page,
    required this.difficulty,
    this.resumeSnapshot,
  });

  final ColoringPage page;
  final PixelDifficulty difficulty;
  final PixelProgressSnapshot? resumeSnapshot;

  static const _paperBackground = 'assets/images/ausmalhintergund.png';

  @override
  State<PixelPaintScreen> createState() => _PixelPaintScreenState();
}

class _PixelPaintScreenState extends State<PixelPaintScreen>
    with TickerProviderStateMixin {
  Future<PixelPuzzle>? _puzzleFuture;
  PixelPuzzle? _puzzle;
  List<PaintSwatch> _swatches = const [];
  late List<bool> _filled;
  int _paintTick = 0;
  int _selectedNumber = 1;
  int _filledCount = 0;
  bool _celebrating = false;
  bool _showFinishActions = false;
  bool _exitAdShown = false;
  bool _saveInFlight = false;
  Timer? _autoSaveTimer;
  Uint8List? _finishedPng;
  late final AnimationController _celebrateController;
  final TransformationController _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _puzzleFuture = _load();
  }

  Future<PixelPuzzle> _load() async {
    final resume = widget.resumeSnapshot;
    if (resume != null &&
        resume.pageId == widget.page.id &&
        resume.cells.isNotEmpty) {
      final puzzle = resume.toPuzzle();
      _puzzle = puzzle;
      _filled = List<bool>.from(resume.filled);
      if (_filled.length != puzzle.totalCells) {
        _filled = List<bool>.filled(puzzle.totalCells, false);
      }
      _filledCount = _filled.where((f) => f).length;
      _selectedNumber = resume.selectedNumber.clamp(1, puzzle.palette.length);
      _swatches = PaintCatalog.numberedFromImageColors([
        for (final entry in puzzle.palette) entry.color,
      ]);
      if (resume.completed && _filledCount >= puzzle.totalCells) {
        _finishedPng = await PixelExporter.renderPng(
          puzzle: puzzle,
          filled: List<bool>.filled(puzzle.totalCells, true),
          cellSize: 20,
          emptyAsLightGray: false,
        );
      }
      return puzzle;
    }

    final puzzle = await PixelQuantizer.fromAsset(
      widget.page.assetPath,
      difficulty: widget.difficulty,
    );
    _puzzle = puzzle;
    _filled = List<bool>.filled(puzzle.totalCells, false);
    _filledCount = 0;
    _selectedNumber = 1;
    _swatches = PaintCatalog.numberedFromImageColors([
      for (final entry in puzzle.palette) entry.color,
    ]);
    return puzzle;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _celebrateController.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _scheduleAutoSave() {
    if (_filledCount == 0 || _celebrating) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_persistProgress(completed: false));
    });
  }

  Future<void> _persistProgress({required bool completed}) async {
    final puzzle = _puzzle;
    if (puzzle == null || _filledCount == 0) return;
    if (_saveInFlight) return;
    _saveInFlight = true;
    try {
      final snapshot = PixelProgressSnapshot.fromPuzzle(
        pageId: widget.page.id,
        puzzle: puzzle,
        filled: _filled,
        selectedNumber: _selectedNumber,
        completed: completed || _filledCount >= puzzle.totalCells,
      );
      final preview = await PixelExporter.renderPreviewWithCanvas(
        puzzle: puzzle,
        filled: completed
            ? List<bool>.filled(puzzle.totalCells, true)
            : _filled,
      );
      if (!mounted) return;
      await context.read<PixelProgressStore>().saveSnapshot(
            snapshot,
            previewPng: preview,
          );
    } catch (e, st) {
      debugPrint('Pixel progress save failed: $e\n$st');
    } finally {
      _saveInFlight = false;
    }
  }

  Future<void> _showExitAdOnce() async {
    if (_exitAdShown) return;
    _exitAdShown = true;
    await AdsService.showInterstitial();
  }

  Future<void> _leave() async {
    _autoSaveTimer?.cancel();
    await _persistProgress(completed: false);
    await _showExitAdOnce();
    if (mounted) Navigator.of(context).pop();
  }

  void _onCellTap(int x, int y) {
    final puzzle = _puzzle;
    if (puzzle == null || _celebrating) return;

    final i = y * puzzle.cols + x;
    if (_filled[i]) return;

    final cellNumber = puzzle.cells[i] + 1;
    if (cellNumber != _selectedNumber) {
      HapticFeedback.lightImpact();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _filled[i] = true;
      _filledCount++;
      _paintTick++;
    });
    _scheduleAutoSave();

    if (_filledCount >= puzzle.totalCells) {
      unawaited(_onComplete());
    } else if (_remainingFor(_selectedNumber) == 0) {
      for (final swatch in _swatches) {
        final n = swatch.number ?? 0;
        if (n > 0 && _remainingFor(n) > 0) {
          setState(() => _selectedNumber = n);
          break;
        }
      }
    }
  }

  Future<void> _onComplete() async {
    if (_celebrating) return;
    final puzzle = _puzzle!;
    setState(() {
      _celebrating = true;
      _showFinishActions = false;
    });
    HapticFeedback.mediumImpact();

    final allFilled = List<bool>.filled(puzzle.totalCells, true);
    _finishedPng = await PixelExporter.renderPng(
      puzzle: puzzle,
      filled: allFilled,
      cellSize: 24,
      emptyAsLightGray: false,
    );
    await _persistProgress(completed: true);

    await _celebrateController.forward(from: 0);
    if (!mounted) return;
    setState(() => _showFinishActions = true);
  }

  Future<void> _saveToPhotos() async {
    final bytes = _finishedPng;
    if (bytes == null) return;
    try {
      final granted = await Gal.requestAccess();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte Zugriff auf Fotos erlauben.'),
          ),
        );
        return;
      }
      await Gal.putImageBytes(
        bytes,
        name: 'fantasy_color_pixel_${widget.page.id}',
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('In Fotos gespeichert!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _closeAfterFinish() async {
    await _showExitAdOnce();
    if (mounted) Navigator.of(context).pop();
  }

  int _remainingFor(int number) {
    final puzzle = _puzzle;
    if (puzzle == null) return 0;
    final idx = number - 1;
    var left = 0;
    for (var i = 0; i < puzzle.cells.length; i++) {
      if (!_filled[i] && puzzle.cells[i] == idx) left++;
    }
    return left;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_leave());
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              PixelPaintScreen._paperBackground,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            FutureBuilder<PixelPuzzle>(
              future: _puzzleFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Pixelbild konnte nicht erstellt werden.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Color(0xFFFFD56A),
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Ganzes Bild wird verpixelt…',
                          style: TextStyle(
                            color: Color(0xFFFFE7A0),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final puzzle = snapshot.data!;
                final progress = _filledCount / puzzle.totalCells;

                return SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(56, 12, 8, 12),
                                child: InteractiveViewer(
                                  transformationController: _transform,
                                  minScale: 0.8,
                                  maxScale: 5,
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: puzzle.cols / puzzle.rows,
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          void paintAt(Offset local) {
                                            final cellW =
                                                constraints.maxWidth /
                                                    puzzle.cols;
                                            final cellH =
                                                constraints.maxHeight /
                                                    puzzle.rows;
                                            final x = (local.dx / cellW)
                                                .floor()
                                                .clamp(0, puzzle.cols - 1);
                                            final y = (local.dy / cellH)
                                                .floor()
                                                .clamp(0, puzzle.rows - 1);
                                            _onCellTap(x, y);
                                          }

                                          return Listener(
                                            behavior: HitTestBehavior.opaque,
                                            onPointerDown: (e) =>
                                                paintAt(e.localPosition),
                                            onPointerMove: (e) {
                                              if (e.buttons == 0) return;
                                              paintAt(e.localPosition);
                                            },
                                            child: CustomPaint(
                                              painter: _PixelGridPainter(
                                                puzzle: puzzle,
                                                filled: _filled,
                                                selectedNumber:
                                                    _selectedNumber,
                                                paintTick: _paintTick,
                                              ),
                                              size: Size(
                                                constraints.maxWidth,
                                                constraints.maxHeight,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              left: 12,
                              child: SilverBackButton(
                                onPressed: () => unawaited(_leave()),
                              ),
                            ),
                            Positioned(
                              top: 14,
                              right: 16,
                              child: _ProgressPill(progress: progress),
                            ),
                            if (_celebrating)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: _showFinishActions,
                                  child: AnimatedBuilder(
                                    animation: _celebrateController,
                                    builder: (context, _) {
                                      return CustomPaint(
                                        painter: _SparklePainter(
                                          progress:
                                              _celebrateController.value,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (_showFinishActions)
                              Positioned.fill(
                                child: _FinishOverlay(
                                  title: widget.page.title,
                                  onSave: () => unawaited(_saveToPhotos()),
                                  onClose: () =>
                                      unawaited(_closeAfterFinish()),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!_showFinishActions)
                        PixelPaintRail(
                          swatches: _swatches,
                          selectedNumber: _selectedNumber,
                          remainingOf: _remainingFor,
                          onSelect: (n) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedNumber = n);
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishOverlay extends StatelessWidget {
  const _FinishOverlay({
    required this.title,
    required this.onSave,
    required this.onClose,
  });

  final String title;
  final VoidCallback onSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.55,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2B3B66),
                  Color(0xFF1A2744),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFD56A).withValues(alpha: 0.55),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFFFD56A),
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Wunderbar!',
                    style: TextStyle(
                      color: Color(0xFFFFE7A0),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dein Pixelbild ist fertig.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _FinishButton(
                          label: 'In Fotos',
                          filled: true,
                          onPressed: onSave,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FinishButton(
                          label: 'Fertig',
                          filled: false,
                          onPressed: onClose,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinishButton extends StatelessWidget {
  const _FinishButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: filled
                ? const LinearGradient(
                    colors: [
                      Color(0xFFFFF0C2),
                      Color(0xFFFFD56A),
                      Color(0xFFE0A93A),
                    ],
                  )
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: filled
                  ? const Color(0xFFFFE7A0)
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: filled
                    ? const Color(0xFF2A2410)
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(
          color: const Color(0xFFFFD56A).withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          '$pct %',
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

class _PixelGridPainter extends CustomPainter {
  _PixelGridPainter({
    required this.puzzle,
    required this.filled,
    required this.selectedNumber,
    required this.paintTick,
  });

  final PixelPuzzle puzzle;
  final List<bool> filled;
  final int selectedNumber;
  final int paintTick;

  static const _targetGray = Color(0xFF8B95A8);
  static const _emptyFill = Color(0xFFF7F8FA);
  static const _numberOnEmpty = Color(0xFF2A3348);
  static const _numberOnTarget = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / puzzle.cols;
    final cellH = size.height / puzzle.rows;
    final cellMin = math.min(cellW, cellH);
    final gridPaint = Paint()
      ..color = const Color(0xFF2A3348).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellMin < 12 ? 0.4 : 0.7;

    final fontSize = (cellMin * 0.55).clamp(5.0, 22.0);

    for (var y = 0; y < puzzle.rows; y++) {
      for (var x = 0; x < puzzle.cols; x++) {
        final i = y * puzzle.cols + x;
        final number = puzzle.cells[i] + 1;
        final color = puzzle.palette[puzzle.cells[i]].color;
        final rect = Rect.fromLTWH(x * cellW, y * cellH, cellW, cellH);

        if (filled[i]) {
          canvas.drawRect(rect, Paint()..color = color);
        } else {
          final isTarget = number == selectedNumber;
          canvas.drawRect(rect, Paint()..color = _emptyFill);
          canvas.drawRect(
            rect,
            Paint()..color = color.withValues(alpha: isTarget ? 0.2 : 0.12),
          );
          if (isTarget) {
            canvas.drawRect(
              rect,
              Paint()..color = _targetGray.withValues(alpha: 0.72),
            );
          }

          final tp = TextPainter(
            text: TextSpan(
              text: '$number',
              style: TextStyle(
                color: isTarget ? _numberOnTarget : _numberOnEmpty,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                height: 1,
                shadows: isTarget
                    ? const [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: cellW);
          tp.paint(
            canvas,
            Offset(
              rect.left + (cellW - tp.width) / 2,
              rect.top + (cellH - tp.height) / 2,
            ),
          );
        }
        canvas.drawRect(rect, gridPaint);
      }
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(2),
      ),
      Paint()
        ..color = const Color(0xFF243044).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _PixelGridPainter oldDelegate) {
    return oldDelegate.paintTick != paintTick ||
        oldDelegate.selectedNumber != selectedNumber ||
        oldDelegate.puzzle != puzzle;
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    final paint = Paint()..color = const Color(0xFFFFE7A0);
    for (var i = 0; i < 28; i++) {
      final t = (progress + i * 0.03) % 1.0;
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * (0.3 + t * 0.7);
      final r = 1.5 + rnd.nextDouble() * 3.5 * (1 - (t - 0.5).abs() * 2);
      paint.color = Color.lerp(
        const Color(0xFFFFE7A0),
        const Color(0xFFFFB347),
        rnd.nextDouble(),
      )!
          .withValues(alpha: (1 - t) * 0.85);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
