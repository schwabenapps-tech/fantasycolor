import 'package:flutter/material.dart';

/// Kleines Badge für gespeicherten Mal-Fortschritt in der Galerie.
class ProgressBadge extends StatelessWidget {
  const ProgressBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A44).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: const Color(0xFF7AD7A8).withValues(alpha: 0.7)),
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
              Icons.palette_rounded,
              size: compact ? 12 : 14,
              color: const Color(0xFF7AD7A8),
            ),
            if (!compact) ...[
              const SizedBox(width: 5),
              const Text(
                'Weiter',
                style: TextStyle(
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
