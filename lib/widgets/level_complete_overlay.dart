import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gemeinsame Level-Complete-Ansicht: Fade-in, Konfetti, Buttons, Fade-out.
class LevelCompleteOverlay extends StatefulWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
    this.onReady,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  /// Nach Fade-in + kurzem Moment (Buttons sichtbar).
  final VoidCallback? onReady;

  @override
  State<LevelCompleteOverlay> createState() => LevelCompleteOverlayState();
}

class LevelCompleteOverlayState extends State<LevelCompleteOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fade;
  late final AnimationController _confetti;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  bool _showActions = false;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _fadeAnim = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);
    _scaleAnim = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _fade, curve: Curves.easeOutBack),
    );
    _runIntro();
  }

  Future<void> _runIntro() async {
    await _fade.forward();
    if (!mounted) return;
    setState(() => _showActions = true);
    widget.onReady?.call();
  }

  /// Sanft ausblenden, dann [true] zurückgeben.
  Future<void> fadeOut() async {
    if (_dismissing) return;
    _dismissing = true;
    if (mounted) setState(() => _showActions = false);
    await _fade.reverse();
  }

  @override
  void dispose() {
    _fade.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fade, _confetti]),
      builder: (context, _) {
        final t = _fadeAnim.value;
        return Opacity(
          opacity: t,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.42 * t),
              ),
              IgnorePointer(
                child: _ConfettiRain(
                  progress: _confetti.value,
                  intensity: t,
                ),
              ),
              Center(
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFD56A),
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFFD56A)
                                  .withValues(alpha: 0.55),
                              blurRadius: 18,
                            ),
                            const Shadow(
                              color: Color(0xAA000000),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(
                              color: Color(0xAA000000),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: _showActions ? 1 : 0,
                        duration: const Duration(milliseconds: 280),
                        child: IgnorePointer(
                          ignoring: !_showActions,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 26),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 10,
                              children: widget.actions,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _ConfettiRain extends StatelessWidget {
  const _ConfettiRain({
    required this.progress,
    required this.intensity,
  });

  final double progress;
  final double intensity;

  static const _colors = <Color>[
    Color(0xFFFFD56A),
    Color(0xFFFF85A1),
    Color(0xFFC9A6FF),
    Color(0xFF6EE0FF),
    Color(0xFFB6F5C8),
    Color(0xFFFFB347),
    Color(0xFFFF6B9D),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: List.generate(42, (i) {
        final seed = i * 19.7;
        final x = ((math.sin(seed) * 0.5 + 0.5) + i * 0.017) % 1.0;
        final speed = 0.55 + (i % 7) * 0.08;
        final drift = math.sin(progress * math.pi * 2 + seed) * 18;
        final y = ((progress * speed) + (i * 0.07)) % 1.15 - 0.08;
        final pieceSize = 5.0 + (i % 5) * 2.4;
        final spin = progress * (4 + i % 5) + seed;
        final opacity =
            (intensity * (0.55 + (i % 4) * 0.1)).clamp(0.0, 0.95);

        return Positioned(
          left: size.width * x + drift,
          top: size.height * y,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: spin,
              child: i.isEven
                  ? Icon(
                      Icons.auto_awesome_rounded,
                      size: pieceSize,
                      color: _colors[i % _colors.length],
                    )
                  : Container(
                      width: pieceSize * 0.7,
                      height: pieceSize * 1.15,
                      decoration: BoxDecoration(
                        color: _colors[i % _colors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
            ),
          ),
        );
      }),
    );
  }
}

/// Goldener Aktions-Button für Level-Complete.
class LevelCompleteActionButton extends StatelessWidget {
  const LevelCompleteActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: filled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF0C2),
                      Color(0xFFFFD56A),
                      Color(0xFFE0A93A),
                    ],
                  )
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: filled
                  ? const Color(0xFFFFE7A0)
                  : Colors.white.withValues(alpha: 0.35),
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD56A).withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: filled
                    ? const Color(0xFF3A2810)
                    : Colors.white.withValues(alpha: 0.92),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled
                      ? const Color(0xFF3A2810)
                      : Colors.white.withValues(alpha: 0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
