import 'package:flutter/material.dart';

import '../providers/coloring_session.dart';

/// Kleiner, unaufdringlicher Fortschrittsbalken + Sticker-Ziel-Icon.
class StickerCoverageBar extends StatelessWidget {
  const StickerCoverageBar({
    super.key,
    required this.session,
  });

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final ratio = session.paintedCoverageRatio();
        final ready = ratio >= ColoringSession.stickerUnlockCoverage;
        final display = (ratio / ColoringSession.stickerUnlockCoverage)
            .clamp(0.0, 1.0);
        return IgnorePointer(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: ratio < 0.02 ? 0.35 : 0.9,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: Colors.black.withValues(alpha: 0.28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FractionallySizedBox(
                    widthFactor: display,
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: ready
                              ? const [Color(0xFFB6F5C8), Color(0xFF3DDC84)]
                              : const [Color(0xFFFFE8A8), Color(0xFFFFB347)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.sticky_note_2_rounded,
                  size: 14,
                  color: ready
                      ? const Color(0xFF3DDC84)
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
