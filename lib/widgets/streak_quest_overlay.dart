import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../services/streak_service.dart';

/// Magie-Portal: zeigt die heutige Streak-Aufgabe.
class StreakQuestOverlay extends StatelessWidget {
  const StreakQuestOverlay({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final streak = context.watch<StreakService>();
    final done = streak.playedToday;
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final titleSize = shortest < 360 ? 26.0 : 32.0;
    final bodySize = shortest < 360 ? 14.0 : 16.0;

    return Material(
      color: const Color(0xFF1A0B2E).withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFB84D),
                      Color(0xFFFF7A45),
                      Color(0xFFC94A2A),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFFF1B0).withValues(alpha: 0.85),
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8C42).withValues(alpha: 0.5),
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
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: titleSize * 1.1,
                        color: const Color(0xFFFFF6C8),
                        shadows: const [
                          Shadow(color: Color(0xAA000000), blurRadius: 10),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.streakQuestTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFF8E8),
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          shadows: const [
                            Shadow(
                              color: Color(0xAA000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.streakDays(streak.count.clamp(0, 9999)),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFF0C8).withValues(alpha: 0.95),
                          fontSize: bodySize + 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t.streakQuestTask,
                          style: TextStyle(
                            color: const Color(0xFFFFF6C8).withValues(alpha: 0.9),
                            fontSize: bodySize - 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.black.withValues(alpha: 0.22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                done
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                color: done
                                    ? const Color(0xFFB6F5C8)
                                    : const Color(0xFFFFF1B0),
                                size: 26,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  done ? t.streakQuestDone : t.streakQuestTodo,
                                  style: TextStyle(
                                    color: const Color(0xFFFFF8E8),
                                    fontSize: bodySize,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t.streakQuestHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFE8C8).withValues(alpha: 0.9),
                          fontSize: bodySize - 1,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _StreakCloseButton(
                        label: t.streakQuestClose,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onClose();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakCloseButton extends StatefulWidget {
  const _StreakCloseButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_StreakCloseButton> createState() => _StreakCloseButtonState();
}

class _StreakCloseButtonState extends State<_StreakCloseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 100),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFF6C8),
                Color(0xFFFFE27A),
                Color(0xFFFFB84D),
              ],
            ),
            border: Border.all(color: const Color(0xFFFFF1B0), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB84D).withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Color(0xFF4A1F0A),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
