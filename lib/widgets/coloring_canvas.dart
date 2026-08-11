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

class _ColoringCanvasState extends State<ColoringCanvas> {
  final TransformationController _transform = TransformationController();
  ui.Image? _frame;
  int _frameGeneration = -1;
  bool _encoding = false;

  @override
  void initState() {
    super.initState();
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
    _transform.dispose();
    _frame?.dispose();
    super.dispose();
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
    final allowPan = widget.session.tool == PaintTool.brush ||
        widget.session.eraserClearsFills;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sheetSize = _sheetSizeFor(constraints.biggest);
        // Nur Pinch-Zoom (zwei Finger) — kein Doppel-Tap-Reset.
        return InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 6,
          panEnabled: allowPan,
          scaleEnabled: true,
          boundaryMargin: const EdgeInsets.all(160),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Center(
              child: SizedBox(
                width: sheetSize.width,
                height: sheetSize.height,
                child: _PaintSurface(
                  bitmap: widget.bitmap,
                  session: widget.session,
                  sheetSize: sheetSize,
                  frame: _frame,
                ),
              ),
            ),
          ),
        );
      },
    );
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
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
          size: isEraser ? 28 : _strokeSizeFor(style!.category),
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

  void _onPointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer == _paintPointer) {
      if (_pendingTapLocal != null && !_tapExceededSlop && !_isMultiTouch) {
        widget.session.applyFillAt(_toImage(_pendingTapLocal!));
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

  double _strokeSizeFor(PaintCategory category) {
    return switch (category) {
      PaintCategory.solid => 14,
      PaintCategory.pastel => 18,
      PaintCategory.watercolor => 22,
      PaintCategory.glow => 16,
      PaintCategory.glitter => 15,
    };
  }
}
