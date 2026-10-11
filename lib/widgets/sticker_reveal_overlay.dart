import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/sticker_catalog.dart';
import '../utils/image_source.dart';

/// Zeigt einen neu erhaltenen Sticker groß + Konfetti (ohne Box-Hintergrund).
class StickerRevealOverlay extends StatefulWidget {
  const StickerRevealOverlay({
    super.key,
    required this.sticker,
    required this.onDismiss,
    this.title = 'New sticker!',
  });

  final StickerEntry sticker;
  final VoidCallback onDismiss;
  final String title;

  @override
  State<StickerRevealOverlay> createState() => _StickerRevealOverlayState();
}

class _StickerRevealOverlayState extends State<StickerRevealOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _confetti;
  late final AnimationController _pop;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _popScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
    );
    _pop.forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    // Deutlich größer, aber Portrait/Landscape-sicher.
    final stickerSide = landscape
        ? (size.shortestSide * 0.78).clamp(240.0, 360.0)
        : (size.width * 0.78).clamp(260.0, 400.0);
    final titleSize = landscape ? 22.0 : 26.0;

    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, _) => _StickerConfettiRain(
                  progress: _confetti.value,
                  intensity: 1,
                ),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _pop,
                builder: (context, _) {
                  return Transform.scale(
                    scale: _popScale.value,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: landscape ? 20 : 12,
                        vertical: landscape ? 8 : 12,
                      ),
                      child: landscape
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: stickerSide,
                                  height: stickerSide,
                                  child: Image(
                                    image: imageProviderFor(
                                      widget.sticker.assetPath,
                                    ),
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: const Color(0xFFFFE7A0),
                                          fontSize: titleSize,
                                          fontWeight: FontWeight.w800,
                                          shadows: const [
                                            Shadow(
                                              color: Color(0xAA000000),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _GoldenYayButton(
                                        onPressed: widget.onDismiss,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFFFFE7A0),
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w800,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0xAA000000),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: stickerSide,
                                  height: stickerSide,
                                  child: Image(
                                    image: imageProviderFor(
                                      widget.sticker.assetPath,
                                    ),
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _GoldenYayButton(onPressed: widget.onDismiss),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldenYayButton extends StatelessWidget {
  const _GoldenYayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF0B8),
            Color(0xFFFFD56A),
            Color(0xFFE8A020),
          ],
        ),
        border: Border.all(color: const Color(0xFFFFF6D0), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99FFD56A),
            blurRadius: 16,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 44, vertical: 16),
            child: Text(
              'Yay!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF4A3208),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickerConfettiRain extends StatelessWidget {
  const _StickerConfettiRain({
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
      children: List.generate(48, (i) {
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
