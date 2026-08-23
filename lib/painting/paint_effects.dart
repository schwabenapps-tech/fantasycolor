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
  final count = (shortest * 2.4).clamp(36, 160).toInt();
  final radiusBase = (shortest * 0.08).clamp(3.2, 18.0);

  canvas.save();
  canvas.clipPath(path);

  final fillPaint = Paint()..style = PaintingStyle.fill;
  final glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);

  for (var i = 0; i < count; i++) {
    final x = bounds.left + random.nextDouble() * bounds.width;
    final y = bounds.top + random.nextDouble() * bounds.height;
    final pos = Offset(x, y);
    final radius = radiusBase * (0.35 + random.nextDouble() * 1.05);
    final roll = random.nextDouble();

    final Color bright;
    if (roll < 0.4) {
      bright = Colors.white;
    } else if (roll < 0.75) {
      bright = Color.lerp(Colors.white, base, 0.2)!;
    } else {
      bright = Color.lerp(const Color(0xFFFFE29A), Colors.white, 0.35)!;
    }

    glowPaint.color = bright.withValues(alpha: 0.6);
    canvas.drawCircle(pos, radius * 2.1, glowPaint);

    fillPaint.color = bright.withValues(alpha: 0.88 + random.nextDouble() * 0.12);
    canvas.drawCircle(pos, radius, fillPaint);

    // Kreuz-Sternchen für echten Glitzer-Look.
    if (random.nextDouble() > 0.35) {
      final arm = radius * (1.8 + random.nextDouble() * 1.2);
      final star = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = math.max(1.1, radius * 0.4)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x - arm, y), Offset(x + arm, y), star);
      canvas.drawLine(Offset(x, y - arm), Offset(x, y + arm), star);

      if (random.nextDouble() > 0.5) {
        final diag = arm * 0.7;
        canvas.drawLine(
          Offset(x - diag, y - diag),
          Offset(x + diag, y + diag),
          star,
        );
        canvas.drawLine(
          Offset(x - diag, y + diag),
          Offset(x + diag, y - diag),
          star,
        );
      }
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
