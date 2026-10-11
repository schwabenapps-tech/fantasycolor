import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../data/paint_catalog.dart';
import '../painting/coloring_bitmap.dart';
import '../providers/coloring_session.dart';
import 'freehand_stroke_painter.dart';

/// Zoombares PNG-Ausmalblatt mit Flood-Fill und Pen.
///
/// Pinch = Zoomen (im Viewport geclippt), bei Zoom verschieben
/// (Fill: 1 Finger, Pen: 2 Finger). Doppeltipp / Rauszoomen → weich zurück.
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
  /// Pan erst nach Zoom-Geste freischalten — kein Rebuild mitten im Pinch.
  bool _panLatched = false;
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

  void _onSessionChanged() {
    if (!mounted) return;
    // Nur Bitmap-Frame neu — kein setState bei jedem Stroke (sonst Zoom-Ruckler).
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
                  sheetSize: sheetSize,
                  transform: _transform,
                  panEnabled: _panLatched && _panAllowedForTool,
                  onDoubleTapAt: _onSoftZoom,
                  onInteractionEnd: _onZoomInteractionEnd,
                  child: _PaintSurface(
                    bitmap: widget.bitmap,
                    session: widget.session,
                    sheetSize: sheetSize,
                    frame: _frame,
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
    // Weich zurück zur Normalposition — kein harter Snap, kein nachträglicher Clamp.
    if (scale <= 1.08) {
      _animateTo(Matrix4.identity());
      return;
    }
    // Matrix unverändert lassen (= genau dort bleiben, wo die Geste endete).
    final zoomed = true;
    final pan = _panAllowedForTool;
    if (zoomed != _wasZoomed || pan != _panLatched) {
      _wasZoomed = zoomed;
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

/// Geclipptes Zoom-Fenster: natives Boundary, kein Post-Clamp (kein Springen).
class _ZoomViewport extends StatelessWidget {
  const _ZoomViewport({
    required this.sheetSize,
    required this.transform,
    required this.panEnabled,
    required this.onDoubleTapAt,
    required this.onInteractionEnd,
    required this.child,
  });

  final Size sheetSize;
  final TransformationController transform;
  final bool panEnabled;
  final ValueChanged<Offset> onDoubleTapAt;
  final VoidCallback onInteractionEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) => onDoubleTapAt(details.localPosition),
      onDoubleTap: () {},
      child: InteractiveViewer(
        transformationController: transform,
        minScale: 1,
        maxScale: 8,
        panEnabled: panEnabled,
        scaleEnabled: true,
        constrained: true,
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        // Endliches Margin: Flutter begrenzt selbst (flüssig), Blatt bleibt im Fenster.
        boundaryMargin: const EdgeInsets.all(48),
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
  });

  final ColoringBitmap bitmap;
  final ColoringSession session;
  final Size sheetSize;
  final ui.Image? frame;

  @override
  State<_PaintSurface> createState() => _PaintSurfaceState();
}

class _PaintSurfaceState extends State<_PaintSurface> {
  static const _tapSlop = 12.0;

  FreehandStroke? _localStroke;
  final Set<int> _pointers = <int>{};
  Offset? _pendingTapLocal;
  bool _tapExceededSlop = false;
  int? _paintPointer;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  @override
  void didUpdateWidget(covariant _PaintSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSession);
      widget.session.addListener(_onSession);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
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

  void _onPointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_isMultiTouch) {
      _cancelPendingTap();
      _cancelLocalStroke();
      return;
    }

    _paintPointer = event.pointer;
    final session = widget.session;
    final tool = session.tool;
    final local = event.localPosition;

    if (tool == PaintTool.brush ||
        (tool == PaintTool.eraser && session.eraserClearsFills)) {
      _pendingTapLocal = local;
      _tapExceededSlop = false;
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
      _cancelPendingTap();
      _cancelLocalStroke();
      return;
    }

    if (_pendingTapLocal != null && event.pointer == _paintPointer) {
      if ((event.localPosition - _pendingTapLocal!).distance > _tapSlop) {
        _tapExceededSlop = true;
      }
      return;
    }

    final stroke = _localStroke;
    if (stroke == null || event.pointer != _paintPointer) return;
    stroke.points.add(
      PointVector(event.localPosition.dx, event.localPosition.dy),
    );
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent event) async {
    _pointers.remove(event.pointer);
    if (event.pointer == _paintPointer) {
      if (_pendingTapLocal != null && !_tapExceededSlop && !_isMultiTouch) {
        await widget.session.applyFillAt(_toImage(_pendingTapLocal!));
      }
      _cancelPendingTap();
      _endLocalStroke();
      _paintPointer = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer == _paintPointer) {
      _cancelPendingTap();
      _cancelLocalStroke();
      _paintPointer = null;
    }
  }

  void _cancelPendingTap() {
    _pendingTapLocal = null;
    _tapExceededSlop = false;
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
