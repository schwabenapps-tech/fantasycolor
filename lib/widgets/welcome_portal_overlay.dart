import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Erststart-Willkommen — spielerisches Portal, kein „Dokument“-Dialog.
class WelcomePortalOverlay extends StatefulWidget {
  const WelcomePortalOverlay({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<WelcomePortalOverlay> createState() => _WelcomePortalOverlayState();
}

class _WelcomePortalOverlayState extends State<WelcomePortalOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _sparkle;
  late final AnimationController _bounce;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _bounceScale;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOutBack),
    );
    _bounceScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _bounce, curve: Curves.easeInOut),
    );

    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _sparkle.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _finish() {
    HapticFeedback.lightImpact();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final titleSize = shortest < 360 ? 28.0 : 34.0;
    final bodySize = shortest < 360 ? 15.0 : 17.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _sparkle, _bounce]),
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: const Color(0xFF1A0B2E).withValues(
                  alpha: 0.72 * _fade.value,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _WelcomeSparklePainter(
                    progress: _sparkle.value,
                    intensity: _fade.value,
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: _fade.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF6B3FA0),
                                Color(0xFF3D1F6E),
                                Color(0xFF2A1450),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFFE8B4FF)
                                  .withValues(alpha: 0.75),
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB07CFF)
                                    .withValues(alpha: 0.45),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                              const BoxShadow(
                                color: Color(0x88000000),
                                blurRadius: 18,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: titleSize * 0.85,
                                  color: const Color(0xFFFFE27A),
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xFFB07CFF),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Welcome, little\nadventurer!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFFFFE8FF),
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                    letterSpacing: 0.4,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0xFFB07CFF),
                                        blurRadius: 16,
                                      ),
                                      Shadow(
                                        color: Color(0xAA000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'A fairy world awaits —\n'
                                  'color · puzzle · explore\n'
                                  'magic at your own pace.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFFE8D4FF)
                                        .withValues(alpha: 0.95),
                                    fontSize: bodySize,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                    letterSpacing: 0.2,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0x66000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 22),
                                ScaleTransition(
                                  scale: _bounceScale,
                                  child: _LetsGoButton(onPressed: _finish),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LetsGoButton extends StatefulWidget {
  const _LetsGoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_LetsGoButton> createState() => _LetsGoButtonState();
}

class _LetsGoButtonState extends State<_LetsGoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "Let's go",
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 100),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFE27A),
                  Color(0xFFFFB84D),
                  Color(0xFFFF8C42),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFF1B0),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB84D).withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                const BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              child: Text(
                "Let's go!",
                style: TextStyle(
                  color: Color(0xFF3A1848),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeSparklePainter extends CustomPainter {
  _WelcomeSparklePainter({
    required this.progress,
    required this.intensity,
  });

  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.01) return;
    final rnd = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 28; i++) {
      final x = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final drift = ((progress + i * 0.07) % 1.0);
      final y = (baseY + drift * size.height * 0.15) % size.height;
      final twinkle =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin((progress * 6 + i) * math.pi));
      paint.color = Color.lerp(
        const Color(0xFFE8B4FF),
        const Color(0xFFFFF6C8),
        rnd.nextDouble(),
      )!
          .withValues(alpha: 0.25 * intensity * twinkle);
      final r = 1.2 + rnd.nextDouble() * 2.4;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeSparklePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}
