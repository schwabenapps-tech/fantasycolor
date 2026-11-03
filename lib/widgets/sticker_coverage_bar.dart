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
    final stickerSize = landscape ? 48.0 : 44.0;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final ratio = session.paintedCoverageRatio();
        final ready = ratio >= ColoringSession.stickerUnlockCoverage;
        final display = (ratio / ColoringSession.stickerUnlockCoverage)
            .clamp(0.0, 1.0);
        return IgnorePointer(
          child: Row(
            children: [
              SizedBox(
                width: stickerSize,
                height: stickerSize,
                child: Image.asset(
                  stickerAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1,
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
              ),
            ],
          ),
        );
      },
    );
  }
}
