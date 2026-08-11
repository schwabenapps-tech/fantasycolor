import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../data/paint_catalog.dart';
import '../painting/paint_effects.dart';
import '../providers/coloring_session.dart';

/// Zeichnet freie Stift-/Radierer-Striche mit Kategorie-Effekten.
class FreehandStrokePainter extends CustomPainter {
  FreehandStrokePainter({
    required this.strokes,
    required this.generation,
    this.activeStroke,
  });

  final List<FreehandStroke> strokes;
  final FreehandStroke? activeStroke;
  final int generation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (activeStroke != null) {
      _paintStroke(canvas, activeStroke!);
    }
    canvas.restore();
  }

  void _paintStroke(Canvas canvas, FreehandStroke stroke) {
    if (stroke.points.isEmpty) return;

    final outline = getStroke(
      stroke.points,
      options: StrokeOptions(
        size: stroke.size,
        thinning: stroke.isEraser ? 0.2 : 0.55,
        smoothing: stroke.category == PaintCategory.watercolor ? 0.7 : 0.5,
        streamline: 0.45,
        simulatePressure: true,
        isComplete: true,
      ),
    );
    if (outline.isEmpty) return;

    final path = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (var i = 1; i < outline.length; i++) {
      path.lineTo(outline[i].dx, outline[i].dy);
    }
    path.close();

    if (stroke.isEraser) {
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.clear
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final color = _strokeColor(stroke);
    if (stroke.category == PaintCategory.glow) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );

    if (stroke.category == PaintCategory.glitter) {
      paintGlitterEffect(
        canvas,
        path,
        stroke.color,
        seed: stroke.points.length,
      );
    }
  }

  Color _strokeColor(FreehandStroke stroke) {
    switch (stroke.category) {
      case PaintCategory.pastel:
        return stroke.color.withValues(alpha: 0.8);
      case PaintCategory.watercolor:
        return stroke.color.withValues(alpha: 0.45);
      case PaintCategory.solid:
      case PaintCategory.glow:
      case PaintCategory.glitter:
        return stroke.color;
    }
  }

  @override
  bool shouldRepaint(covariant FreehandStrokePainter oldDelegate) {
    if (activeStroke != null || oldDelegate.activeStroke != null) {
      return true;
    }
    return oldDelegate.generation != generation;
  }
}
