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

/// Goldene Werbe-Pille für gesperrte Galerie-Kacheln.
class AdUnlockBadge extends StatelessWidget {
  const AdUnlockBadge({
    super.key,
    required this.label,
    this.compact = false,
    this.large = false,
  });

  static const asset = 'assets/images/videobelohnung.stern.png';

  final String label;
  final bool compact;
  /// Etwas größere Pille (z. B. Druckvorlagen).
  final bool large;

  static const _fill = Color(0xFFE8C56A);
  static const _border = Color(0xFFC9A03A);
  static const _ink = Color(0xFF4A3208);

  @override
  Widget build(BuildContext context) {
    final iconSize = large ? (compact ? 52.0 : 58.0) : (compact ? 46.0 : 52.0);
    final fontSize = large ? (compact ? 12.0 : 13.0) : (compact ? 11.5 : 12.5);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _fill.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _border.withValues(alpha: 0.95),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 5 : 6,
            compact ? 3 : 4,
            compact ? 10 : 12,
            compact ? 3 : 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                asset,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              SizedBox(width: compact ? 3 : 4),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: _ink,
                  fontSize: fontSize,
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

/// Abdunklung + Werbe-Pille über dem Vorschaubild.
class AdUnlockCover extends StatelessWidget {
  const AdUnlockCover({
    super.key,
    required this.label,
    this.compact = false,
    this.large = false,
  });

  final String label;
  final bool compact;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AdUnlockBadge(
              label: label,
              compact: compact,
              large: large,
            ),
          ),
        ),
      ],
    );
  }
}
