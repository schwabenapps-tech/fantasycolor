import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../data/paint_catalog.dart';
import '../painting/coloring_bitmap.dart';
import '../providers/coloring_session.dart';
import 'freehand_stroke_painter.dart';

/// Zoombares PNG-Ausmalblatt mit Flood-Fill.
///
/// Pinch = Zoomen. Bei Zoom: 1 Finger = Pan, Tip = Fill,
/// kurz halten dann ziehen = Drag-Fill (Viewport dabei eingefroren).
/// Ungezoomt: Tip + Drag-über-Flächen füllt.
class ColoringCanvas extends StatefulWidget {
  const ColoringCanvas({
    super.key,
    required this.bitmap,
    required this.session,
  });

  final ColoringBitmap bitmap;
  final ColoringSession session;

  @override
  State<ColoringCanvas> createState() => _ColoringCanvasState();
}

class _ColoringCanvasState extends State<ColoringCanvas>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  ui.Image? _frame;
  int _frameGeneration = -1;
  bool _encoding = false;
  bool _wasZoomed = false;
  bool _panLatched = false;
  bool _fillCapturing = false;
  Matrix4? _lockedTransform;
  bool _lockingTransform = false;
  late final AnimationController _zoomController;
  Animation<Matrix4>? _matrixAnimation;
  VoidCallback? _matrixListener;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _transform.addListener(_onTransformChanged);
    widget.session.addListener(_onSessionChanged);
    widget.session.attachBitmap(widget.bitmap, notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildFrame();
    });
  }

  @override
  void didUpdateWidget(covariant ColoringCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSessionChanged);
      widget.session.addListener(_onSessionChanged);
    }
    if (oldWidget.bitmap != widget.bitmap) {
      widget.session.attachBitmap(widget.bitmap, notify: false);
      _rebuildFrame();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _transform.removeListener(_onTransformChanged);
    _clearMatrixAnimation();
    _zoomController.dispose();
    _transform.dispose();
    _frame?.dispose();
    super.dispose();
  }

  void _clearMatrixAnimation() {
    if (_matrixListener != null && _matrixAnimation != null) {
      _matrixAnimation!.removeListener(_matrixListener!);
    }
    _matrixListener = null;
    _matrixAnimation = null;
  }

  void _onTransformChanged() {
    // Während Zoom-Drag-Fill Viewport einfrieren — sonst beißt sich Pan mit Fill.
    final locked = _lockedTransform;
    if (locked == null || _lockingTransform) return;
    if (_transform.value == locked) return;
    _lockingTransform = true;
    _transform.value = locked.clone();
    _lockingTransform = false;
  }

  void _onFillCaptureChanged(bool capturing) {
    if (_fillCapturing == capturing) return;
    if (capturing) {
      _lockedTransform = _transform.value.clone();
    } else {
      _lockedTransform = null;
    }
    if (!mounted) return;
    setState(() => _fillCapturing = capturing);
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (widget.session.bitmapGeneration != _frameGeneration) {
      _rebuildFrame();
    }
  }

  Future<void> _rebuildFrame() async {
    if (_encoding) return;
    _encoding = true;
    final generation = widget.session.bitmapGeneration;
    try {
      final image = await widget.bitmap.toUiImage();
      if (!mounted) {
        image.dispose();
        return;
      }
      // Alten Frame erst nach Swap disposen — verhindert Weißblitz.
      final previous = _frame;
      setState(() {
        _frame = image;
        _frameGeneration = generation;
      });
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          previous.dispose();
        });
      }
    } finally {
      _encoding = false;
      if (mounted && widget.session.bitmapGeneration != _frameGeneration) {
        _rebuildFrame();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final sheetSize = _sheetSizeFor(viewport);
        widget.session.sheetSize = sheetSize;

        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: _ZoomViewport(
                  viewportSize: viewport,
                  sheetSize: sheetSize,
                  transform: _transform,
                  panEnabled:
                      _panLatched && _panAllowedForTool && !_fillCapturing,
                  onDoubleTapAt: _onSoftZoom,
                  onInteractionEnd: _onZoomInteractionEnd,
                  child: ListenableBuilder(
                    listenable: _transform,
                    builder: (context, _) {
                      final scale = _transform.value.getMaxScaleOnAxis();
                      return _PaintSurface(
                        bitmap: widget.bitmap,
                        session: widget.session,
                        sheetSize: sheetSize,
                        frame: _frame,
                        zoomed: scale > 1.08,
                        onFillCaptureChanged: _onFillCaptureChanged,
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_wasZoomed)
              Positioned(
                left: 10,
                bottom: 10,
                child: _ZoomResetChip(
                  onPressed: () => _resetZoom(animated: true),
                ),
              ),
          ],
        );
      },
    );
  }

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.05;

  bool get _panAllowedForTool {
    final tool = widget.session.tool;
    if (tool == PaintTool.pen) return false;
    if (tool == PaintTool.eraser && !widget.session.eraserClearsFills) {
      return false;
    }
    return true;
  }

  void _onSoftZoom(Offset viewportPos) {
    if (_transform.value.getMaxScaleOnAxis() > 1.2) {
      _resetZoom(animated: true);
    }
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
    _wasZoomed = false;
    _panLatched = false;
    if (mounted) setState(() {});
  }

  void _onZoomInteractionEnd() {
    final scale = _transform.value.getMaxScaleOnAxis();
    if (scale <= 1.08) {
      _animateTo(Matrix4.identity());
      return;
    }
    final pan = _panAllowedForTool;
    if (!_wasZoomed || pan != _panLatched) {
      _wasZoomed = true;
      _panLatched = pan;
      if (mounted) setState(() {});
    }
  }

  void _animateTo(Matrix4 target) {
    _clearMatrixAnimation();
    _zoomController.stop();

    final goingHome = target.getMaxScaleOnAxis() <= 1.001;
    _matrixAnimation = Matrix4Tween(
      begin: _transform.value.clone(),
      end: target,
    ).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
    );
    _matrixListener = () {
      _transform.value = _matrixAnimation!.value;
    };
    _matrixAnimation!.addListener(_matrixListener!);
    _zoomController.forward(from: 0).whenComplete(() {
      _clearMatrixAnimation();
      if (goingHome) {
        _transform.value = Matrix4.identity();
        _wasZoomed = false;
        _panLatched = false;
      } else {
        _wasZoomed = _isZoomed;
        _panLatched = _wasZoomed && _panAllowedForTool;
      }
      if (mounted) setState(() {});
    });
  }

  Size _sheetSizeFor(Size max) {
    final ratio = widget.bitmap.width / widget.bitmap.height;
    var width = max.width;
    var height = width / ratio;
    if (height > max.height) {
      height = max.height;
      width = height * ratio;
    }
    return Size(width, height);
  }
}

/// Zoom-Fenster: Blatt zentriert; Boundary-Slack damit Hochformat beim
/// Zoomen nicht sofort am Rand festklemmt (Pan erst ab Zoom aktiv).
class _ZoomViewport extends StatelessWidget {
  const _ZoomViewport({
    required this.viewportSize,
    required this.sheetSize,
    required this.transform,
    required this.panEnabled,
    required this.onDoubleTapAt,
    required this.onInteractionEnd,
    required this.child,
  });

  final Size viewportSize;
  final Size sheetSize;
  final TransformationController transform;
  final bool panEnabled;
  final ValueChanged<Offset> onDoubleTapAt;
  final VoidCallback onInteractionEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final slack = (viewportSize.shortestSide * 0.22).clamp(72.0, 160.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) => onDoubleTapAt(details.localPosition),
      onDoubleTap: () {},
      child: InteractiveViewer(
        transformationController: transform,
        minScale: 1,
        maxScale: 6,
        panEnabled: panEnabled,
        scaleEnabled: true,
        constrained: true,
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        boundaryMargin: EdgeInsets.all(slack),
        onInteractionEnd: (_) => onInteractionEnd(),
        child: Center(
          child: SizedBox(
            width: sheetSize.width,
            height: sheetSize.height,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PaintSurface extends StatefulWidget {
  const _PaintSurface({
    required this.bitmap,
    required this.session,
    required this.sheetSize,
    required this.frame,
    required this.zoomed,
    required this.onFillCaptureChanged,
  });

  final ColoringBitmap bitmap;
  final ColoringSession session;
  final Size sheetSize;
  final ui.Image? frame;
  final bool zoomed;
  final ValueChanged<bool> onFillCaptureChanged;

  @override
  State<_PaintSurface> createState() => _PaintSurfaceState();
}

class _PaintSurfaceState extends State<_PaintSurface> {
  /// Abstand zwischen Drag-Samples (Blatt-Koordinaten, ungezoomt).
  static const _dragSamplePx = 12.0;
  /// Zoom: Sample in Bildschirm-px — sonst wirkt 12 Blatt-px viel zu empfindlich.
  static const _dragSampleGlobalZoomed = 36.0;
  /// Nur bei Zoom: erst ab hier Pan statt Tip (Finger wackelt leicht).
  static const _panSlopGlobal = 42.0;
  /// Zoom: halten, dann Drag-Fill; sofort ziehen = Pan.
  static const _zoomDragFillHold = Duration(milliseconds: 380);

  FreehandStroke? _localStroke;
  final Set<int> _pointers = <int>{};
  bool _fillGesture = false;
  bool _armedTapFill = false;
  bool _zoomPanCommitted = false;
  Offset? _downGlobal;
  Offset? _downLocal;
  Offset? _lastFillSampleLocal;
  Offset? _lastFillSampleGlobal;
  int? _paintPointer;
  int _lastStrokeGen = -1;
  Timer? _zoomHoldTimer;

  @override
  void initState() {
    super.initState();
    _lastStrokeGen = widget.session.strokeGeneration;
    widget.session.addListener(_onSession);
  }

  @override
  void didUpdateWidget(covariant _PaintSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSession);
      widget.session.addListener(_onSession);
      _lastStrokeGen = widget.session.strokeGeneration;
    }
  }

  @override
  void dispose() {
    _zoomHoldTimer?.cancel();
    if (_fillGesture) {
      widget.onFillCaptureChanged(false);
    }
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    // Nur bei Strich-Overlay neu bauen — nicht bei jedem Fill-Flag.
    if (widget.session.strokeGeneration != _lastStrokeGen) {
      _lastStrokeGen = widget.session.strokeGeneration;
      if (mounted) setState(() {});
    }
  }

  Offset _toImage(Offset local) {
    return Offset(
      local.dx / widget.sheetSize.width * widget.bitmap.width,
      local.dy / widget.sheetSize.height * widget.bitmap.height,
    );
  }

  bool get _isMultiTouch => _pointers.length > 1;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final frame = widget.frame;

    return ColoredBox(
      color: Colors.white,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (frame != null)
              RawImage(image: frame, fit: BoxFit.fill)
            else
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            CustomPaint(
              painter: FreehandStrokePainter(
                strokes: session.strokes,
                activeStroke: _localStroke,
                generation: session.strokeGeneration,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isFillTool {
    final session = widget.session;
    final tool = session.tool;
    return tool == PaintTool.brush ||
        (tool == PaintTool.eraser && session.eraserClearsFills);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_isMultiTouch) {
      _cancelZoomHold();
      _cancelFillArm();
      _endFillGesture();
      _cancelLocalStroke();
      return;
    }

    _paintPointer = event.pointer;
    final session = widget.session;
    final tool = session.tool;
    final local = event.localPosition;

    if (_isFillTool) {
      _downGlobal = event.position;
      _downLocal = local;
      _zoomPanCommitted = false;
      _lastFillSampleLocal = local;

      if (widget.zoomed) {
        // Zoom: sofort ziehen = Pan; halten = Drag-Fill; Tip = eine Fläche.
        _armedTapFill = true;
        _fillGesture = false;
        _zoomHoldTimer?.cancel();
        _zoomHoldTimer = Timer(_zoomDragFillHold, () {
          if (!mounted || _paintPointer != event.pointer) return;
          if (_zoomPanCommitted || _isMultiTouch) return;
          // Long-Press → Drag-Fill; Pan/Zoom dabei eingefroren.
          _armedTapFill = false;
          _fillGesture = true;
          final start = _downLocal ?? local;
          _lastFillSampleLocal = start;
          _lastFillSampleGlobal = _downGlobal ?? event.position;
          widget.onFillCaptureChanged(true);
          session.beginFillGesture();
          unawaited(session.applyFillAt(_toImage(start)));
        });
        return;
      }

      // Ungezoomt: sofort Drag-Fill.
      _armedTapFill = false;
      _fillGesture = true;
      session.beginFillGesture();
      unawaited(session.applyFillAt(_toImage(local)));
      return;
    }

    if (tool == PaintTool.pen || tool == PaintTool.eraser) {
      final isEraser = tool == PaintTool.eraser;
      final style = session.currentFillStyle();
      if (!isEraser && style == null) return;

      setState(() {
        _localStroke = FreehandStroke(
          points: [PointVector(local.dx, local.dy)],
          color: style?.color ?? const Color(0x00000000),
          category: style?.category ?? PaintCategory.solid,
          isEraser: isEraser,
          size: isEraser ? 28 : session.penStrokeSize(),
        );
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.contains(event.pointer)) return;
    if (_isMultiTouch) {
      _cancelZoomHold();
      _cancelFillArm();
      _endFillGesture();
      _cancelLocalStroke();
      return;
    }
    if (event.pointer != _paintPointer) return;

    // Zoom + Bewegung vor Long-Press → Pan, kein Fill.
    if (widget.zoomed &&
        !_fillGesture &&
        !_zoomPanCommitted &&
        _downGlobal != null &&
        (event.position - _downGlobal!).distance >= _panSlopGlobal) {
      _zoomPanCommitted = true;
      _cancelZoomHold();
      _cancelFillArm();
      return;
    }

    if (_fillGesture) {
      final local = event.localPosition;
      if (widget.zoomed) {
        final lastG = _lastFillSampleGlobal;
        if (lastG == null ||
            (event.position - lastG).distance >= _dragSampleGlobalZoomed) {
          _lastFillSampleGlobal = event.position;
          _lastFillSampleLocal = local;
          unawaited(widget.session.applyFillAt(_toImage(local)));
        }
      } else {
        final last = _lastFillSampleLocal;
        if (last == null || (local - last).distance >= _dragSamplePx) {
          _lastFillSampleLocal = local;
          unawaited(widget.session.applyFillAt(_toImage(local)));
        }
      }
      return;
    }

    if (_armedTapFill || _zoomPanCommitted) return;

    final stroke = _localStroke;
    if (stroke == null) return;
    stroke.points.add(
      PointVector(event.localPosition.dx, event.localPosition.dy),
    );
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer != _paintPointer) return;

    _cancelZoomHold();

    if (_armedTapFill && !_zoomPanCommitted && !_isMultiTouch) {
      // Immer Down-Position — nicht die letzte Move-Sample (genauer).
      final local = _downLocal ?? event.localPosition;
      unawaited(widget.session.applyFillAt(_toImage(local)));
    } else if (_fillGesture) {
      _endFillGesture();
    }

    _cancelFillArm();
    _endLocalStroke();
    _paintPointer = null;
    _downGlobal = null;
    _downLocal = null;
    _zoomPanCommitted = false;
    _lastFillSampleLocal = null;
    _lastFillSampleGlobal = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer == _paintPointer) {
      _cancelZoomHold();
      _cancelFillArm();
      _endFillGesture();
      _cancelLocalStroke();
      _paintPointer = null;
      _downGlobal = null;
      _downLocal = null;
      _zoomPanCommitted = false;
      _lastFillSampleLocal = null;
      _lastFillSampleGlobal = null;
    }
  }

  void _cancelZoomHold() {
    _zoomHoldTimer?.cancel();
    _zoomHoldTimer = null;
  }

  void _cancelFillArm() {
    _armedTapFill = false;
  }

  void _endFillGesture() {
    if (!_fillGesture) return;
    _fillGesture = false;
    widget.onFillCaptureChanged(false);
    widget.session.endFillGesture();
  }

  void _cancelLocalStroke() {
    if (_localStroke == null) return;
    setState(() => _localStroke = null);
  }

  void _endLocalStroke() {
    final stroke = _localStroke;
    if (stroke == null) return;
    if (stroke.points.length == 1) {
      stroke.points.add(
        PointVector(stroke.points.first.x + 0.1, stroke.points.first.y + 0.1),
      );
    }
    setState(() => _localStroke = null);
    widget.session.commitStroke(stroke);
  }
}

class _ZoomResetChip extends StatelessWidget {
  const _ZoomResetChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text(
                'Reset',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
