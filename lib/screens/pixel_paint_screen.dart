import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/paint_catalog.dart';
import '../models/coloring_page.dart';
import '../models/pixel_puzzle.dart';
import '../painting/pixel_export.dart';
import '../painting/pixel_quantizer.dart';
import '../providers/pixel_progress_store.dart';
import '../services/ads_service.dart';
import '../services/gallery_export.dart';
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  bool _saveDirty = false;
  bool _saveCompletedFlag = false;
  Future<void>? _activeSave;
  Timer? _autoSaveTimer;
  Uint8List? _finishedPng;
  late final AnimationController _celebrateController;
  late final AnimationController _zoomController;
  final TransformationController _transform = TransformationController();
  Animation<Matrix4>? _matrixAnimation;
  VoidCallback? _matrixListener;

  /// 1 Finger = halten & ziehen zum Malen; 2+ Finger = Pinch-Zoom (kein Malen).
  final Set<int> _pointers = <int>{};
  int? _paintPointer;
  bool _strokeDidPaint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _puzzleFuture = _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_persistProgress(completed: false));
    }
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
        _celebrating = true;
        _showFinishActions = true;
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
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _clearMatrixAnimation();
    _zoomController.dispose();
    _celebrateController.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _clearMatrixAnimation() {
    if (_matrixListener != null && _matrixAnimation != null) {
      _matrixAnimation!.removeListener(_matrixListener!);
    }
    _matrixListener = null;
    _matrixAnimation = null;
  }

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.05;

  Size _sheetSizeFor(Size max, double aspect) {
    var width = max.width;
    var height = width / aspect;
    if (height > max.height) {
      height = max.height;
      width = height * aspect;
    }
    return Size(width, height);
  }

  void _onSoftZoom(Offset viewportPos) {
    final current = _transform.value.getMaxScaleOnAxis();
    if (current > 1.2) {
      _resetZoom(animated: true);
      return;
    }

    const targetScale = 3.0;
    final matrix = Matrix4.identity()
      ..translateByDouble(viewportPos.dx, viewportPos.dy, 0, 1)
      ..scaleByDouble(targetScale, targetScale, 1, 1)
      ..translateByDouble(-viewportPos.dx, -viewportPos.dy, 0, 1);
    _animateTo(matrix);
  }

  void _resetZoom({bool animated = true}) {
    if (animated) {
      _animateTo(Matrix4.identity());
    } else {
      _snapToIdentity();
    }
  }

  void _snapToIdentity() {
    _clearMatrixAnimation();
    _zoomController.stop();
    _transform.value = Matrix4.identity();
    if (mounted) setState(() {});
  }

  void _onZoomInteractionEnd() {
    final scale = _transform.value.getMaxScaleOnAxis();
    // Pinch-Rauszoomen hält oft Translation → sofort zentrieren, nicht animieren.
    if (scale <= 1.08) {
      _snapToIdentity();
      return;
    }
    if (mounted) setState(() {});
  }

  void _animateTo(Matrix4 target) {
    _clearMatrixAnimation();
    _zoomController.stop();

    _matrixAnimation = Matrix4Tween(
      begin: _transform.value.clone(),
      end: target,
    ).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
    );
    _matrixListener = () {
      _transform.value = _matrixAnimation!.value;
      if (mounted) setState(() {});
    };
    _matrixAnimation!.addListener(_matrixListener!);
    _zoomController.forward(from: 0).whenComplete(_clearMatrixAnimation);
  }

  void _scheduleAutoSave() {
    if (_filledCount == 0 || _celebrating) return;
    _autoSaveTimer?.cancel();
    // Mittel/Schwer: Vorschau-Render dauert länger — etwas mehr Debounce,
    // aber nie Saves verwerfen (siehe _persistProgress-Warteschlange).
    _autoSaveTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_persistProgress(completed: false));
    });
  }

  /// Speichert zuverlässig auch bei vielen Pixeln: parallele Aufrufe werden
  /// nicht verworfen, sondern nach dem laufenden Save nochmal mit aktuellem Stand geschrieben.
  Future<void> _persistProgress({required bool completed}) async {
    final puzzle = _puzzle;
    if (puzzle == null || _filledCount == 0) return;

    if (completed) _saveCompletedFlag = true;
    _saveDirty = true;

    if (_saveInFlight) {
      return _activeSave ?? Future<void>.value();
    }

    _saveInFlight = true;
    final done = Completer<void>();
    _activeSave = done.future;
    try {
      while (_saveDirty) {
        if (!mounted) break;
        _saveDirty = false;
        final markCompleted = _saveCompletedFlag ||
            _filledCount >= puzzle.totalCells;
        // Snapshot jetzt — nicht den Stand vom Save-Start einer älteren Runde.
        final filledCopy = List<bool>.from(_filled);
        final selected = _selectedNumber;
        final snapshot = PixelProgressSnapshot.fromPuzzle(
          pageId: widget.page.id,
          puzzle: puzzle,
          filled: filledCopy,
          selectedNumber: selected,
          completed: markCompleted,
        );
        final preview = await PixelExporter.renderPreviewWithCanvas(
          puzzle: puzzle,
          filled: markCompleted
              ? List<bool>.filled(puzzle.totalCells, true)
              : filledCopy,
        );
        if (!mounted) break;
        await context.read<PixelProgressStore>().saveSnapshot(
              snapshot,
              previewPng: preview,
            );
      }
    } catch (e, st) {
      debugPrint('Pixel progress save failed: $e\n$st');
    } finally {
      _saveInFlight = false;
      _activeSave = null;
      if (!done.isCompleted) done.complete();
      // Falls während finally noch Dirty gesetzt wurde: nochmal speichern.
      if (_saveDirty && mounted && _filledCount > 0) {
        unawaited(_persistProgress(completed: _saveCompletedFlag));
      }
    }
  }

  Future<void> _showExitAdOnce() async {
    if (_exitAdShown) return;
    _exitAdShown = true;
    if (_celebrating) {
      await AdsService.showColoringFinishChoiceInterstitial();
    } else {
      await AdsService.showColoringLeaveInterstitial();
    }
  }

  Future<void> _leave() async {
    _autoSaveTimer?.cancel();
    await _persistProgress(completed: false);
    // Warte auf evtl. Nachzieh-Save (Mittel hat große Raster → langsam).
    var guard = 0;
    while (_saveInFlight && guard < 5) {
      guard++;
      await (_activeSave ?? Future<void>.value());
    }
    await _showExitAdOnce();
    if (mounted) Navigator.of(context).pop();
  }

  void _onCellTap(int x, int y, {bool fromDrag = false}) {
    final puzzle = _puzzle;
    if (puzzle == null || _celebrating) return;

    final i = y * puzzle.cols + x;
    if (_filled[i]) return;

    final cellNumber = puzzle.cells[i] + 1;
    if (cellNumber != _selectedNumber) {
      if (!fromDrag) HapticFeedback.lightImpact();
      return;
    }

    // Beim Ziehen nur einmal pro Strich vibrieren — sonst ruckelt's.
    if (!fromDrag || !_strokeDidPaint) {
      HapticFeedback.selectionClick();
    }
    _strokeDidPaint = true;

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
      await GalleryExport.savePngBytes(
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
        SnackBar(content: Text('$e')),
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
                final railWidth = _showFinishActions
                    ? 0.0
                    : PixelPaintRail.widthOf(context);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Vollflächiger Zoom wie bei Ausmalbildern.
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final sheet = _sheetSizeFor(
                            constraints.biggest,
                            puzzle.cols / puzzle.rows,
                          );
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTapDown: (details) =>
                                _onSoftZoom(details.localPosition),
                            onDoubleTap: () {},
                            child: InteractiveViewer(
                              transformationController: _transform,
                              minScale: 1,
                              maxScale: 8,
                              // Immer aus: 1 Finger malt (halten & ziehen).
                              // Verschieben/Zoomen: Pinch mit 2 Fingern.
                              panEnabled: false,
                              scaleEnabled: true,
                              constrained: true,
                              clipBehavior: Clip.hardEdge,
                              boundaryMargin: const EdgeInsets.all(120),
                              onInteractionUpdate: (_) {
                                if (mounted) setState(() {});
                              },
                              onInteractionEnd: (_) =>
                                  _onZoomInteractionEnd(),
                              child: Center(
                                child: SizedBox(
                                  width: sheet.width,
                                  height: sheet.height,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Opacity(
                                        opacity: 0.38,
                                        child: Image.asset(
                                          widget.page.assetPath,
                                          fit: BoxFit.fill,
                                          filterQuality:
                                              FilterQuality.medium,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                      ColoredBox(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                      ),
                                      Listener(
                                        behavior: HitTestBehavior.opaque,
                                        onPointerDown: (e) {
                                          _pointers.add(e.pointer);
                                          if (_pointers.length > 1) {
                                            _paintPointer = null;
                                            return;
                                          }
                                          _paintPointer = e.pointer;
                                          _strokeDidPaint = false;
                                          final cellW =
                                              sheet.width / puzzle.cols;
                                          final cellH =
                                              sheet.height / puzzle.rows;
                                          final x = (e.localPosition.dx /
                                                  cellW)
                                              .floor()
                                              .clamp(0, puzzle.cols - 1);
                                          final y = (e.localPosition.dy /
                                                  cellH)
                                              .floor()
                                              .clamp(0, puzzle.rows - 1);
                                          _onCellTap(
                                            x,
                                            y,
                                            fromDrag: false,
                                          );
                                        },
                                        onPointerMove: (e) {
                                          if (_pointers.length != 1) {
                                            return;
                                          }
                                          if (_paintPointer != e.pointer) {
                                            return;
                                          }
                                          if (e.buttons == 0) return;
                                          final cellW =
                                              sheet.width / puzzle.cols;
                                          final cellH =
                                              sheet.height / puzzle.rows;
                                          final x = (e.localPosition.dx /
                                                  cellW)
                                              .floor()
                                              .clamp(0, puzzle.cols - 1);
                                          final y = (e.localPosition.dy /
                                                  cellH)
                                              .floor()
                                              .clamp(0, puzzle.rows - 1);
                                          _onCellTap(
                                            x,
                                            y,
                                            fromDrag: true,
                                          );
                                        },
                                        onPointerUp: (e) {
                                          _pointers.remove(e.pointer);
                                          if (_paintPointer == e.pointer) {
                                            _paintPointer = null;
                                          }
                                        },
                                        onPointerCancel: (e) {
                                          _pointers.remove(e.pointer);
                                          if (_paintPointer == e.pointer) {
                                            _paintPointer = null;
                                          }
                                        },
                                        child: CustomPaint(
                                          painter: _PixelGridPainter(
                                            puzzle: puzzle,
                                            filled: _filled,
                                            selectedNumber: _selectedNumber,
                                            paintTick: _paintTick,
                                          ),
                                          size: sheet,
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
                    ),
                    SafeArea(
                      child: Stack(
                        children: [
                          if (_isZoomed)
                            Positioned(
                              left: 10,
                              bottom: 10,
                              child: _ZoomResetChip(onPressed: _resetZoom),
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
                            right: 16 + railWidth,
                            child: _ProgressPill(progress: progress),
                          ),
                        ],
                      ),
                    ),
                    if (!_showFinishActions)
                      Align(
                        alignment: Alignment.centerRight,
                        child: PixelPaintRail(
                          swatches: _swatches,
                          selectedNumber: _selectedNumber,
                          remainingOf: _remainingFor,
                          onSelect: (n) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedNumber = n);
                          },
                        ),
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
                                  progress: _celebrateController.value,
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
                          onClose: () => unawaited(_closeAfterFinish()),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomResetChip extends StatelessWidget {
  const _ZoomResetChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.black.withValues(alpha: 0.45),
            border: Border.all(color: Colors.white54),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text(
                'Ganzes Bild',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
  static const _numberOnEmpty = Color(0xFF243044);
  static const _numberOnTarget = Color(0xFFFFFFFF);

  /// Leerer Schleier — Originalfoto darunter bleibt sichtbar.
  static const _veilAlpha = 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / puzzle.cols;
    final cellH = size.height / puzzle.rows;
    final cellMin = math.min(cellW, cellH);
    final gridPaint = Paint()
      ..color = const Color(0xFF2A3348).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellMin < 10 ? 0.35 : 0.6;

    // Zahlen müssen in die Zelle passen — kein Mindest-Font, der größer als
    // die Zelle ist (bei ~96 Spalten sonst starke Überlappung, v. a. 10–20).
    final maxFont = math.min(cellMin * 0.72, 18.0);
    final numberCache = <int, TextPainter>{};

    TextPainter numberPainter(int number, {required bool isTarget}) {
      final cached = numberCache[number * 2 + (isTarget ? 1 : 0)];
      if (cached != null) return cached;

      var fontSize = maxFont;
      TextPainter layoutAt(double size) {
        return TextPainter(
          text: TextSpan(
            text: '$number',
            style: TextStyle(
              color: isTarget
                  ? _numberOnTarget
                  : _numberOnEmpty.withValues(alpha: 0.88),
              fontSize: size,
              fontWeight: FontWeight.w800,
              height: 1,
              shadows: size >= 6
                  ? (isTarget
                      ? const [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 2,
                          ),
                        ]
                      : const [
                          Shadow(
                            color: Color(0x55FFFFFF),
                            blurRadius: 2,
                          ),
                        ])
                  : null,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
      }

      var tp = layoutAt(fontSize);
      // Zweistellige Zahlen (und enge Zellen) auf Zellenbreite/-höhe schrumpfen.
      final maxW = cellW * 0.92;
      final maxH = cellH * 0.92;
      if (tp.width > maxW || tp.height > maxH) {
        final scale = math.min(maxW / tp.width, maxH / tp.height);
        fontSize = fontSize * scale;
        if (fontSize < 1.0) {
          // Zu klein — kein Label (Zoom vergrößert Zelle+Text gemeinsam).
          final empty = TextPainter(textDirection: TextDirection.ltr)
            ..layout();
          numberCache[number * 2 + (isTarget ? 1 : 0)] = empty;
          return empty;
        }
        tp = layoutAt(fontSize);
      }

      numberCache[number * 2 + (isTarget ? 1 : 0)] = tp;
      return tp;
    }

    // Zellen: ausgefüllt = voll, leer = leichter Schleier + Nummer
    // (Originalfoto liegt als Widget darunter).
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
          canvas.drawRect(
            rect,
            Paint()
              ..color = Colors.white.withValues(
                alpha: isTarget ? _veilAlpha * 0.4 : _veilAlpha,
              ),
          );
          if (isTarget) {
            canvas.drawRect(
              rect,
              Paint()..color = _targetGray.withValues(alpha: 0.4),
            );
          }

          final tp = numberPainter(number, isTarget: isTarget);
          if (tp.width >= 1.0 && tp.height >= 1.0) {
            canvas.save();
            canvas.clipRect(rect);
            tp.paint(
              canvas,
              Offset(
                rect.left + (cellW - tp.width) / 2,
                rect.top + (cellH - tp.height) / 2,
              ),
            );
            canvas.restore();
          }
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
