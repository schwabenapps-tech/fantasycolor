import 'package:flutter/material.dart';

import '../providers/coloring_session.dart';

/// Fortschrittsbalken + „You can do it“-Sticker als klares Ziel-Icon.
class StickerCoverageBar extends StatelessWidget {
  const StickerCoverageBar({
    super.key,
    required this.session,
  });

  final ColoringSession session;

  static const stickerAsset = 'assets/images/you_can_do_it.png';

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.sizeOf(context).width >
        MediaQuery.sizeOf(context).height;
    // Portrait: kurz halten (Top-Bar hat Back + Save + Done).
    final barWidth = landscape ? 108.0 : 64.0;
    final stickerSize = landscape ? 48.0 : 44.0;

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
            opacity: ratio < 0.02 ? 0.4 : 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: barWidth,
                  height: 11,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: Colors.black.withValues(alpha: 0.32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 0.9,
                    ),
                    boxShadow: ready
                        ? const [
                            BoxShadow(
                              color: Color(0x663DDC84),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
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
                const SizedBox(width: 6),
                SizedBox(
                  width: stickerSize,
                  height: stickerSize,
                  child: Opacity(
                    opacity: ready ? 1 : 0.72,
                    child: Image.asset(
                      stickerAsset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
