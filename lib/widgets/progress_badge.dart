import 'package:flutter/material.dart';

/// Kleines Badge für gespeicherten Mal-Fortschritt in der Galerie.
class ProgressBadge extends StatelessWidget {
  const ProgressBadge({
    super.key,
    this.compact = false,
    this.label = 'Weiter',
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
