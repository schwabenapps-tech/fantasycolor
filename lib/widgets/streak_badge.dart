import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../services/streak_service.dart';
import 'streak_quest_overlay.dart';

/// Weiches Magie-Feuer-Badge — tippbar, öffnet die Streak-Aufgabe.
class StreakBadge extends StatefulWidget {
  const StreakBadge({super.key});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _openQuest() {
    HapticFeedback.lightImpact();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'streak-quest',
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return StreakQuestOverlay(
          onClose: () => Navigator.of(context).pop(),
        );
      },
      transitionBuilder: (context, anim, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final streak = context.watch<StreakService>();
    if (!streak.isReady) return const SizedBox.shrink();

    final t = AppStrings.of(context);
    final count = streak.count;

    return Semantics(
      button: true,
      label: t.streakSemantics(count),
      child: GestureDetector(
        onTap: _openQuest,
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, _) {
            final scale =
                1.0 + 0.07 * Curves.easeInOut.transform(_bounce.value);
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: count < 1 ? 0.72 : 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF0A8),
                        Color(0xFFFFB347),
                        Color(0xFFFF7A45),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFF6D0),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8C42).withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(18, 20),
                          painter: _MagicFlamePainter(flicker: _bounce.value),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$count',
                          style: const TextStyle(
                            color: Color(0xFF4A1F0A),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MagicFlamePainter extends CustomPainter {
  _MagicFlamePainter({required this.flicker});

  final double flicker;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sway = (flicker - 0.5) * 2.2;

    final outer = Path()
      ..moveTo(w * 0.5 + sway, 0)
      ..quadraticBezierTo(w * 1.05, h * 0.35, w * 0.82, h * 0.72)
      ..quadraticBezierTo(w * 0.7, h * 1.02, w * 0.5, h)
      ..quadraticBezierTo(w * 0.3, h * 1.02, w * 0.18, h * 0.72)
      ..quadraticBezierTo(w * -0.05, h * 0.35, w * 0.5 + sway, 0)
      ..close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFF6C8),
          Color(0xFFFFB84D),
          Color(0xFFFF5A2A),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(outer, paint);

    final inner = Path()
      ..moveTo(w * 0.5 + sway * 0.4, h * 0.28)
      ..quadraticBezierTo(w * 0.78, h * 0.5, w * 0.62, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 0.95, w * 0.38, h * 0.82)
      ..quadraticBezierTo(w * 0.22, h * 0.5, w * 0.5 + sway * 0.4, h * 0.28)
      ..close();
    canvas.drawPath(
      inner,
      Paint()..color = const Color(0xFFFFF8E0).withValues(alpha: 0.9),
    );

    final sparkY = h * (0.12 + 0.08 * math.sin(flicker * math.pi));
    canvas.drawCircle(
      Offset(w * 0.62 + sway, sparkY),
      1.4,
      Paint()..color = const Color(0xFFFFFBE8),
    );
  }

  @override
  bool shouldRepaint(covariant _MagicFlamePainter oldDelegate) {
    return oldDelegate.flicker != flicker;
  }
}
