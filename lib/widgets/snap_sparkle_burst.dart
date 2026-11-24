import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Kurzer goldener Funken-/Sternenstaub-Burst (Code-Partikel, kein Asset).
class SnapSparkleBurst extends StatelessWidget {
  const SnapSparkleBurst({
    super.key,
    required this.progress,
    required this.center,
    this.count = 10,
    this.radius = 36,
    this.finale = false,
  });

  /// 0 → 1 über die Burst-Dauer.
  final double progress;
  final Offset center;
  final int count;
  final double radius;
  final bool finale;

  static const _colors = <Color>[
    Color(0xFFFFF4C8),
    Color(0xFFFFD56A),
    Color(0xFFFFE7A0),
    Color(0xFFFFC94A),
    Color(0xFFFFF8E0),
  ];

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= 0) return const SizedBox.shrink();

    final n = finale ? math.max(count, 24) : count;
    final maxR = finale ? radius * 1.85 : radius;
    final ease = Curves.easeOutCubic.transform(t);
    final fade = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < n; i++)
            _particle(
              index: i,
              total: n,
              ease: ease,
              fade: fade,
              maxR: maxR,
            ),
        ],
      ),
    );
  }

  Widget _particle({
    required int index,
    required int total,
    required double ease,
    required double fade,
    required double maxR,
  }) {
    final angle = (index / total) * math.pi * 2 + index * 0.17;
    final dist = maxR * ease * (0.55 + (index % 5) * 0.09);
    final x = center.dx + math.cos(angle) * dist;
    final y = center.dy + math.sin(angle) * dist;
    final size = finale
        ? 5.0 + (index % 4) * 2.2
        : 4.0 + (index % 3) * 1.6;
    final color = _colors[index % _colors.length];
    final spin = ease * (4 + index % 3) + angle;
    final opacity = (fade * (finale ? 0.95 : 0.88)).clamp(0.0, 1.0);

    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: spin,
          child: index.isEven
              ? Icon(
                  Icons.auto_awesome_rounded,
                  size: size * 1.35,
                  color: color,
                )
              : Container(
                  width: size * 0.75,
                  height: size * 0.75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: finale ? 6 : 4,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
