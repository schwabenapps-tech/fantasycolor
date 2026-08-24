import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../data/paint_catalog.dart';
import '../painting/coloring_bitmap.dart';
import '../providers/coloring_session.dart';
import 'freehand_stroke_painter.dart';

/// Zoombares PNG-Ausmalblatt mit Flood-Fill und Stift.
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
  late final AnimationController _zoomController;
  Animation<Matrix4>? _matrixAnimation;
  VoidCallback? _matrixListener;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    widget.session.addListener(_onSessionChanged);
    // Kein notify während build/init — sonst crasht AnimatedBuilder.
    widget.session.attachBitmap(widget.bitmap, notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rebuildFrame();
      }
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
    if (widget.session.generation != _frameGeneration) {
      _rebuildFrame();
    } else {
      setState(() {});
    }
  }

  Future<void> _rebuildFrame() async {
    if (_encoding) return;
    _encoding = true;
    final generation = widget.session.generation;
    try {
      final image = await widget.bitmap.toUiImage();
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _frame?.dispose();
        _frame = image;
        _frameGeneration = generation;
      });
    } finally {
      _encoding = false;
      if (mounted && widget.session.generation != _frameGeneration) {
        _rebuildFrame();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sheetSize = _sheetSizeFor(constraints.biggest);
        widget.session.sheetSize = sheetSize;

        return Stack(
          children: [
            Center(
              child: _FramedZoomSheet(
                sheetSize: sheetSize,
                transform: _transform,
                onDoubleTapAt: _onSoftZoom,
                onInteraction: () {
                  if (mounted) setState(() {});
                },
                child: _PaintSurface(
                  bitmap: widget.bitmap,
                  session: widget.session,
                  sheetSize: sheetSize,
                  frame: _frame,
                ),
              ),
            ),
            if (_isZoomed)
              Positioned(
                right: 8,
                bottom: 8,
                child: _ZoomResetChip(onPressed: _resetZoom),
              ),
            if (widget.session.isFilling)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.08),
                    child: const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.05;

  void _onSoftZoom(Offset localPos) {
    final current = _transform.value.getMaxScaleOnAxis();
    if (current > 1.2) {
      _resetZoom();
      return;
    }

    const targetScale = 2.4;
    // Zoom zur Tipp-Stelle, bleibt durch den Rahmen geclippt.
    final matrix = Matrix4.identity()
      ..translateByDouble(localPos.dx, localPos.dy, 0, 1)
      ..scaleByDouble(targetScale, targetScale, 1, 1)
      ..translateByDouble(-localPos.dx, -localPos.dy, 0, 1);
    _animateTo(matrix);
  }

  void _resetZoom() => _animateTo(Matrix4.identity());

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

/// Fester Bilderrahmen: nur Zoomen, kein Verschieben nach draußen.
class _FramedZoomSheet extends StatelessWidget {
  const _FramedZoomSheet({
    required this.sheetSize,
    required this.transform,
    required this.onDoubleTapAt,
    required this.onInteraction,
    required this.child,
  });

  final Size sheetSize;
  final TransformationController transform;
  final ValueChanged<Offset> onDoubleTapAt;
  final VoidCallback onInteraction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: sheetSize.width,
          height: sheetSize.height,
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onDoubleTapDown: (details) => onDoubleTapAt(details.localPosition),
            onDoubleTap: () {},
            child: InteractiveViewer(
              transformationController: transform,
              minScale: 1,
              maxScale: 5,
              panEnabled: false,
              scaleEnabled: true,
              constrained: true,
              clipBehavior: Clip.hardEdge,
              boundaryMargin: EdgeInsets.zero,
              onInteractionUpdate: (_) => onInteraction(),
              onInteractionEnd: (_) => onInteraction(),
              child: SizedBox(
                width: sheetSize.width,
                height: sheetSize.height,
                child: child,
              ),
            ),
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
                generation: session.generation,
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
