import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/puzzle_settings.dart';
import '../screens/puzzle_screen.dart';
import 'jigsaw_layout.dart';

/// Puzzle-Nähte „ritzen“ sich schleichend ins Bild (von innen nach außen).
class PuzzleEtchPainter extends CustomPainter {
  PuzzleEtchPainter({
    required this.progress,
    this.aspect = 1,
    this.seed = 42,
    this.targetPieces = 42,
    this.style = PuzzlePieceStyle.jigsaw,
    this.layout,
  }) : assert(layout != null || targetPieces > 0);

  final double progress;

  /// Nur nötig, wenn [layout] nicht gesetzt ist.
  final double aspect;
  final int seed;
  final int targetPieces;
  final PuzzlePieceStyle style;

  /// Vorhandenes Layout (z. B. laufendes Puzzle) — sonst wird eins erzeugt.
  final JigsawLayout? layout;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || size.isEmpty) return;

    final JigsawLayout used;
    final existing = layout;
    if (existing != null) {
      used = existing;
    } else {
      final grid = PuzzleScreen.gridForDisplayAspect(
        aspect,
        targetCount: targetPieces,
      );
      used = JigsawLayout(
        columns: grid.cols,
        rows: grid.rows,
        style: style,
        random: math.Random(seed),
      );
    }

    final pieces = used.columns * used.rows;
    final density = math.sqrt(pieces / 30.0).clamp(0.7, 2.2);
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.4 / density).clamp(1.0, 2.4)
      ..color = Colors.black.withValues(alpha: 0.42)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.25 / density).clamp(0.65, 1.25)
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = (used.columns - 1) / 2.0;
    final cy = (used.rows - 1) / 2.0;
    final maxDist = math.sqrt(cx * cx + cy * cy).clamp(1.0, 99.0);

    for (var row = 0; row < used.rows; row++) {
      for (var col = 0; col < used.columns; col++) {
        final dist = math.sqrt(
          (col - cx) * (col - cx) + (row - cy) * (row - cy),
        );
        final order = dist / maxDist;
        final start = order * 0.62;
        final local = ((progress - start) / 0.38).clamp(0.0, 1.0);
        if (local <= 0) continue;

        final path = used.piecePath(
          col: col,
          row: row,
          boardSize: size,
        );
        _strokePartial(canvas, path, shadow, local);
        _strokePartial(canvas, path, seam, local);
      }
    }
  }

  void _strokePartial(Canvas canvas, Path path, Paint paint, double t) {
    if (t >= 0.995) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      final end = metric.length * Curves.easeOut.transform(t);
      if (end <= 0.5) continue;
      canvas.drawPath(metric.extractPath(0, end), paint);
    }
  }

  @override
  bool shouldRepaint(covariant PuzzleEtchPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.aspect != aspect ||
      oldDelegate.seed != seed ||
      oldDelegate.targetPieces != targetPieces ||
      oldDelegate.style != style ||
      oldDelegate.layout != layout;
}
