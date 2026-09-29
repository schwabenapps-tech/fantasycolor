import 'package:flutter/material.dart';

/// Gemeinsamer Galerie-Rahmen: Fantasy (Standard) oder Halloween.
enum GalleryFrameStyle { fantasy, halloween }

class GalleryFrame extends StatelessWidget {
  const GalleryFrame({
    super.key,
    required this.child,
    this.style = GalleryFrameStyle.fantasy,
    this.showHalloweenBadge = false,
  });

  final Widget child;
  final GalleryFrameStyle style;
  final bool showHalloweenBadge;

  static const _halloweenOrange = Color(0xFFFF8C42);
  static const _halloweenPurple = Color(0xFF6B3FA0);
  static const _gold = Color(0xFFFFD56A);

  @override
  Widget build(BuildContext context) {
    final isHalloween = style == GalleryFrameStyle.halloween;
    final colors = isHalloween
        ? const [
            Color(0xFFFFF0D6),
            _halloweenOrange,
            _halloweenPurple,
            Color(0xFFFFE0A0),
          ]
        : const [
            Color(0xFFFFF8EC),
            Color(0xFFE8C9A0),
            Color(0xFFC9A06A),
            Color(0xFFF0DCC0),
            Color(0xFFD4B896),
          ];
    final glow = isHalloween ? _halloweenOrange : const Color(0xFFC9A06A);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.42),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: child,
          ),
        ),
        if (isHalloween && showHalloweenBadge)
          const Positioned(
            left: 8,
            top: 8,
            child: _PumpkinBadge(),
          ),
      ],
    );
  }
}

/// Alias für bestehende Halloween-Aufrufe.
class HalloweenFrame extends StatelessWidget {
  const HalloweenFrame({
    super.key,
    required this.child,
    this.showBadge = false,
  });

  final Widget child;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return GalleryFrame(
      style: GalleryFrameStyle.halloween,
      showHalloweenBadge: showBadge,
      child: child,
    );
  }
}

class _PumpkinBadge extends StatelessWidget {
  const _PumpkinBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GalleryFrame._gold, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: GalleryFrame._halloweenOrange.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '🎃',
          style: TextStyle(fontSize: 16, height: 1.1),
        ),
      ),
    );
  }
}

/// Kleines „NEU“-Badge für frische (nicht-Halloween) Motive.
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0C2), Color(0xFFFFD56A), Color(0xFFE0A93A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD56A).withValues(alpha: 0.45),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'NEU',
          style: TextStyle(
            color: Color(0xFF2A2410),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
