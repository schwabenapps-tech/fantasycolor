import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hub_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  static const _backgroundAsset = 'assets/images/fairy_fantasy_color.png';

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onPlay() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const HubScreen(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _backgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            SafeArea(
              child: Align(
                alignment: const Alignment(0, 0.78),
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: FantasyPlayButton(
                    size: size.shortestSide * 0.22,
                    onPressed: _onPlay,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Silberner Fantasy-Play-Button im Stil der Logo-Überschrift.
class FantasyPlayButton extends StatefulWidget {
  const FantasyPlayButton({
    super.key,
    required this.onPressed,
    this.size = 88,
  });

  final VoidCallback onPressed;
  final double size;

  @override
  State<FantasyPlayButton> createState() => _FantasyPlayButtonState();
}

class _FantasyPlayButtonState extends State<FantasyPlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return Semantics(
      button: true,
      label: 'Play',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _FantasyPlayPainter(pressed: _pressed),
            ),
          ),
        ),
      ),
    );
  }
}

class _FantasyPlayPainter extends CustomPainter {
  _FantasyPlayPainter({required this.pressed});

  final bool pressed;

  static const _gemColors = [
    Color(0xFF5EB7FF), // sapphire
    Color(0xFFB07CFF), // amethyst
    Color(0xFF6EE0FF), // aqua
    Color(0xFF9B6CFF), // violet
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    _drawGlow(canvas, center, radius);
    _drawSilverBody(canvas, center, radius);
    _drawFiligreeRing(canvas, center, radius);
    _drawInnerWell(canvas, center, radius);
    _drawGems(canvas, center, radius, size);
    _drawPlayTriangle(canvas, center, radius);
    _drawCrestCrystal(canvas, center, radius, size);
  }

  void _drawGlow(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 1.02,
      Paint()
        ..color = const Color(0xFFA8D4FF).withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      center,
      radius * 0.9,
      Paint()
        ..color = const Color(0xFFC9A6FF).withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _drawSilverBody(Canvas canvas, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius * 0.94);
    canvas.drawCircle(
      center,
      radius * 0.94,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFD8DEE9),
            Color(0xFF8F98A9),
            Color(0xFFF2F5FA),
            Color(0xFFA7B0C1),
            Color(0xFFE8ECF4),
            Color(0xFF7E8798),
            Color(0xFFFFFFFF),
          ],
        ).createShader(rect),
    );

    // Beveled outer rim
    canvas.drawCircle(
      center,
      radius * 0.94,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.045
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFB8C0D0),
            Color(0xFF6F788A),
            Color(0xFFE6EAF2),
          ],
        ).createShader(rect),
    );
  }

  void _drawFiligreeRing(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.018
      ..color = const Color(0xFF5C6578).withValues(alpha: 0.55);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.012
      ..color = const Color(0xFFF7FAFF).withValues(alpha: 0.7);

    // Ornate swirl arcs around the silver rim
    for (var i = 0; i < 8; i++) {
      final start = (i * math.pi / 4) + 0.15;
      final sweep = math.pi / 5;
      final oval = Rect.fromCircle(center: center, radius: radius * 0.86);
      canvas.drawArc(oval, start, sweep, false, ringPaint);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.82),
        start + 0.08,
        sweep * 0.7,
        false,
        highlight,
      );

      // Small flourish curls
      final a = start + sweep * 0.5;
      final tip = Offset(
        center.dx + math.cos(a) * radius * 0.78,
        center.dy + math.sin(a) * radius * 0.78,
      );
      final curl = Path()
        ..moveTo(tip.dx, tip.dy)
        ..quadraticBezierTo(
          tip.dx + math.cos(a + 1.2) * radius * 0.08,
          tip.dy + math.sin(a + 1.2) * radius * 0.08,
          tip.dx + math.cos(a) * radius * 0.05,
          tip.dy + math.sin(a) * radius * 0.05,
        );
      canvas.drawPath(curl, highlight);
    }
  }

  void _drawInnerWell(Canvas canvas, Offset center, double radius) {
    final innerR = radius * 0.62;
    final rect = Rect.fromCircle(center: center, radius: innerR);

    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [
            Color(0xFF3D4F78),
            Color(0xFF1C2742),
            Color(0xFF0B1020),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Silver inset rim
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.035
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFF9AA4B6),
            Color(0xFFE9EEF7),
          ],
        ).createShader(rect),
    );

    // Specular highlight
    canvas.drawCircle(
      center.translate(-radius * 0.22, -radius * 0.24),
      radius * 0.14,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  void _drawGems(Canvas canvas, Offset center, double radius, Size size) {
    for (var i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final gemCenter = Offset(
        center.dx + math.cos(angle) * radius * 0.78,
        center.dy + math.sin(angle) * radius * 0.78,
      );
      final gemR = radius * (i.isEven ? 0.075 : 0.055);
      final color = _gemColors[i % _gemColors.length];

      // Gem glow
      canvas.drawCircle(
        gemCenter,
        gemR * 1.6,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Faceted gem body
      final gemRect = Rect.fromCircle(center: gemCenter, radius: gemR);
      canvas.drawCircle(
        gemCenter,
        gemR,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 1,
            colors: [
              Color.lerp(color, Colors.white, 0.55)!,
              color,
              Color.lerp(color, const Color(0xFF1A1030), 0.45)!,
            ],
          ).createShader(gemRect),
      );

      // Silver bezel
      canvas.drawCircle(
        gemCenter,
        gemR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.008
          ..color = const Color(0xFFE8EEF8),
      );

      // Sparkle
      canvas.drawCircle(
        gemCenter.translate(-gemR * 0.28, -gemR * 0.28),
        gemR * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  void _drawCrestCrystal(Canvas canvas, Offset center, double radius, Size size) {
    // Small crystal cluster at top, echoing the logo crest
    final tip = Offset(center.dx, center.dy - radius * 0.94);
    final crystal = Path()
      ..moveTo(tip.dx, tip.dy - radius * 0.08)
      ..lineTo(tip.dx + radius * 0.055, tip.dy + radius * 0.02)
      ..lineTo(tip.dx, tip.dy + radius * 0.06)
      ..lineTo(tip.dx - radius * 0.055, tip.dy + radius * 0.02)
      ..close();

    canvas.drawPath(
      crystal,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFEAF6FF),
            const Color(0xFF7EC8FF),
            const Color(0xFF4A7AD8),
          ],
        ).createShader(Rect.fromCircle(center: tip, radius: radius * 0.1)),
    );
    canvas.drawPath(
      crystal,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFF5FAFF),
    );
  }

  void _drawPlayTriangle(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx - radius * 0.16, center.dy - radius * 0.26)
      ..quadraticBezierTo(
        center.dx - radius * 0.14,
        center.dy,
        center.dx - radius * 0.16,
        center.dy + radius * 0.26,
      )
      ..lineTo(center.dx + radius * 0.34, center.dy)
      ..close();

    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pressed
              ? const [Color(0xFFE4EAF4), Color(0xFFAEB7C8)]
              : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFDCE3EF),
                  Color(0xFF9AA5B8),
                  Color(0xFFF0F4FA),
                ],
        ).createShader(bounds),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.02
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFF7A8496)],
        ).createShader(bounds),
    );

    // Tiny gem in the play tip
    final gemAt = Offset(center.dx + radius * 0.12, center.dy);
    canvas.drawCircle(
      gemAt,
      radius * 0.035,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFD8F0FF), Color(0xFF5EB7FF), Color(0xFF2F5FBF)],
        ).createShader(Rect.fromCircle(center: gemAt, radius: radius * 0.035)),
    );
  }

  @override
  bool shouldRepaint(covariant _FantasyPlayPainter oldDelegate) {
    return oldDelegate.pressed != pressed;
  }
}
