import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/advent_service.dart';

/// Hintergrund + Schnee für Hub-Kategorien im Winter-UI.
class WinterHubBackdrop extends StatelessWidget {
  const WinterHubBackdrop({
    super.key,
    this.fallbackAsset = 'assets/images/in_app_background.png',
  });

  final String fallbackAsset;

  static const winterAsset = 'assets/images/winterhintergrund.png';

  static String asset([String fallback = 'assets/images/in_app_background.png']) =>
      AdventService.isWinterHubUi() ? winterAsset : fallback;

  @override
  Widget build(BuildContext context) {
    final winter = AdventService.isWinterHubUi();
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          winter ? winterAsset : fallbackAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        if (winter) const WinterAtmosphereOverlay(),
      ],
    );
  }
}

/// Leichter Frost-Rand + Schneeflocken (Winter-Hub / Advent).
class WinterAtmosphereOverlay extends StatefulWidget {
  const WinterAtmosphereOverlay({
    super.key,
    this.snowCount = 18,
    this.frostOpacity = 0.22,
  });

  final int snowCount;
  final double frostOpacity;

  @override
  State<WinterAtmosphereOverlay> createState() =>
      _WinterAtmosphereOverlayState();
}

class _WinterAtmosphereOverlayState extends State<WinterAtmosphereOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<_Snowflake> _flakes;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _flakes = List.generate(widget.snowCount, (_) {
      return _Snowflake(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 1.5 + rng.nextDouble() * 3.5,
        speed: 0.02 + rng.nextDouble() * 0.05,
        drift: (rng.nextDouble() - 0.5) * 0.02,
      );
    });
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (_last == Duration.zero)
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    for (final f in _flakes) {
      f.y += f.speed * dt;
      f.x += f.drift * dt;
      if (f.y > 1.05) {
        f.y = -0.05;
        f.x = math.Random().nextDouble();
      }
      if (f.x < -0.05) f.x = 1.05;
      if (f.x > 1.05) f.x = -0.05;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _FrostPainter(opacity: widget.frostOpacity),
          ),
          CustomPaint(
            painter: _SnowPainter(_flakes),
          ),
        ],
      ),
    );
  }
}

class _Snowflake {
  _Snowflake({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
  });

  double x;
  double y;
  final double size;
  final double speed;
  final double drift;
}

class _FrostPainter extends CustomPainter {
  _FrostPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: opacity),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withValues(alpha: opacity * 0.85),
        ],
        stops: const [0, 0.18, 0.82, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, edge);

    final side = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: opacity * 0.7),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withValues(alpha: opacity * 0.7),
        ],
        stops: const [0, 0.12, 0.88, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, side);
  }

  @override
  bool shouldRepaint(covariant _FrostPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

class _SnowPainter extends CustomPainter {
  _SnowPainter(this.flakes);

  final List<_Snowflake> flakes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (final f in flakes) {
      canvas.drawCircle(
        Offset(f.x * size.width, f.y * size.height),
        f.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}
