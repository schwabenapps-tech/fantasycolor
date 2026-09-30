import 'package:flutter/material.dart';

import '../data/paint_catalog.dart';
import '../providers/coloring_session.dart';
import '../utils/app_layout.dart';

/// Untere Farbleiste: Fill + Eraser, alle Farben ohne Kategorie-Filter.
class PaintBottomBar extends StatelessWidget {
  const PaintBottomBar({
    super.key,
    required this.session,
  });

  final ColoringSession session;

  static double heightOf(BuildContext context) =>
      AppLayout.of(context).paintBarHeight;

  @override
  Widget build(BuildContext context) {
    final barHeight = heightOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: Container(
            height: barHeight + bottomInset,
            padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + bottomInset),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              border: const Border(
                top: BorderSide(color: Colors.white24),
              ),
            ),
            child: Row(
              children: [
                _EraserButton(session: session),
                const SizedBox(width: 10),
                Expanded(child: _ColorStrip(session: session)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EraserButton extends StatelessWidget {
  const _EraserButton({required this.session});

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    final selected = session.tool == PaintTool.eraser;
    final radius = BorderRadius.circular(14);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => session.selectTool(
          selected ? PaintTool.brush : PaintTool.eraser,
        ),
        borderRadius: radius,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: selected
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.16),
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Icon(
            Icons.auto_fix_off_rounded,
            size: 22,
            color: selected ? const Color(0xFF243044) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ColorStrip extends StatelessWidget {
  const _ColorStrip({required this.session});

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    final swatches = session.availableSwatches;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: swatches.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final swatch = swatches[index];
        final selected = session.swatch?.id == swatch.id &&
            session.tool != PaintTool.eraser;
        return Center(
          child: _ColorWell(
            color: swatch.color,
            selected: selected,
            onTap: () => session.selectSwatch(swatch),
          ),
        );
      },
    );
  }
}

class _ColorWell extends StatelessWidget {
  const _ColorWell({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? Colors.white : Colors.transparent,
            border: selected
                ? Border.all(color: const Color(0xFF121826), width: 2.8)
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: selected ? 38 : 44,
            height: selected ? 38 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                width: selected ? 2.4 : 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
