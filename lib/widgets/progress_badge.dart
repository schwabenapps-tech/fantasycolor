import 'package:flutter/material.dart';

/// Kleines Badge für gespeicherten Mal-Fortschritt in der Galerie.
class ProgressBadge extends StatelessWidget {
  const ProgressBadge({
    super.key,
    this.compact = false,
    this.label = 'Continue',
    this.done = false,
  });

  final bool compact;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final accent = done ? const Color(0xFFFFD56A) : const Color(0xFF7AD7A8);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A44).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? Icons.check_rounded : Icons.palette_rounded,
              size: compact ? 12 : 14,
              color: accent,
            ),
            if (!compact) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE8EEF8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Goldenes Play-Badge: Letztes-Event-Motiv — jedes Öffnen mit Werbung.
class AdUnlockBadge extends StatelessWidget {
  const AdUnlockBadge({
    super.key,
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 26.0 : 32.0;
    final playSize = compact ? 14.0 : 17.0;
    return Semantics(
      label: label,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF2C8),
                Color(0xFFFFC857),
                Color(0xFFE8A020),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB84D).withValues(alpha: 0.55),
                blurRadius: 10,
                spreadRadius: 0.5,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '🎬',
              style: TextStyle(
                fontSize: playSize,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
