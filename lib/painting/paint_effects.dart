import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sichtbarer Glitzer-Effekt in lokalen Zeichenkoordinaten.
void paintGlitterEffect(
  Canvas canvas,
  Path path,
  Color base, {
  int seed = 0,
}) {
  final bounds = path.getBounds();
  if (bounds.isEmpty) return;

  final shortest = math.min(bounds.width, bounds.height);
  if (shortest <= 0) return;

  final random = _SparkleRandom(base.toARGB32() ^ bounds.left.toInt() ^ seed);
  final count = (shortest * 1.1).clamp(22, 90).toInt();
  final radiusBase = (shortest * 0.055).clamp(2.8, 16.0);

  canvas.save();
  canvas.clipPath(path);

  final fillPaint = Paint()..style = PaintingStyle.fill;
  final glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

  for (var i = 0; i < count; i++) {
    final x = bounds.left + random.nextDouble() * bounds.width;
    final y = bounds.top + random.nextDouble() * bounds.height;
    final pos = Offset(x, y);
    final radius = radiusBase * (0.35 + random.nextDouble() * 0.9);
    final bright = Color.lerp(
      Colors.white,
      base,
      random.nextDouble() * 0.25,
    )!;

    glowPaint.color = bright.withValues(alpha: 0.55);
    canvas.drawCircle(pos, radius * 1.8, glowPaint);

    fillPaint.color = bright.withValues(alpha: 0.85 + random.nextDouble() * 0.15);
    canvas.drawCircle(pos, radius, fillPaint);

    // Kleine Kreuz-Sternchen für echten Glitzer-Look.
    if (random.nextDouble() > 0.55) {
      final arm = radius * (1.6 + random.nextDouble());
      final star = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = math.max(1.0, radius * 0.35)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x - arm, y), Offset(x + arm, y), star);
      canvas.drawLine(Offset(x, y - arm), Offset(x, y + arm), star);
    }
  }

  canvas.restore();
}

class _SparkleRandom {
  _SparkleRandom(this._state);

  int _state;

  double nextDouble() {
    _state = 0x5DEECE66D * _state + 0xB;
    final bits = (_state >> 8) & 0xFFFFFF;
    return bits / 0x1000000;
  }
}
