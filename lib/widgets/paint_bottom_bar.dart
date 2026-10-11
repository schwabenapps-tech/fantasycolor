import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/paint_catalog.dart';
import '../providers/coloring_session.dart';
import '../utils/app_layout.dart';

/// Untere Farbleiste: Tools + Kategorien/Farben in einer scrollbaren Reihe.
class PaintBottomBar extends StatelessWidget {
  const PaintBottomBar({
    super.key,
    required this.session,
    this.onResetAll,
  });

  final ColoringSession session;

  /// Long-Press auf Undo → alles zurücksetzen (inkl. Progress löschen).
  final VoidCallback? onResetAll;

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
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomInset),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              border: const Border(
                top: BorderSide(color: Colors.white24),
              ),
            ),
            child: _ScrollablePaintTray(
              session: session,
              onResetAll: onResetAll,
            ),
          ),
        );
      },
    );
  }
}

/// Eine horizontale Liste: [Zurück?] [Radierer] [Undo] | Kategorien oder Farben.
class _ScrollablePaintTray extends StatelessWidget {
  const _ScrollablePaintTray({
    required this.session,
    this.onResetAll,
  });

  final ColoringSession session;
  final VoidCallback? onResetAll;

  @override
  Widget build(BuildContext context) {
    final showingColors = session.showingColors;
    final recent = showingColors ? session.recentSwatches : const <PaintSwatch>[];
    final swatches =
        showingColors ? session.availableSwatches : const <PaintSwatch>[];
    final categories =
        showingColors ? const <PaintCategory>[] : PaintCatalog.categories;

    // Tools: Zurück (nur Farben) → Radierer → Undo, dann Inhalt.
    final toolCount = showingColors ? 3 : 2;
    final recentBlock = recent.isEmpty ? 0 : recent.length + 1;
    final contentCount =
        showingColors ? recentBlock + swatches.length : categories.length;
    final itemCount = toolCount + contentCount;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: itemCount,
      separatorBuilder: (_, index) {
        // Nach den Tools etwas mehr Luft vor den Farben/Kategorien.
        if (index == toolCount - 1) {
          return const SizedBox(width: 12);
        }
        return const SizedBox(width: 8);
      },
      itemBuilder: (context, index) {
        if (index < toolCount) {
          return Center(child: _toolAt(index, showingColors));
        }
        var i = index - toolCount;
        if (!showingColors) {
          final category = categories[i];
          return Center(
            child: _PalettePackChip(
              category: category,
              onTap: () => session.selectCategory(category),
            ),
          );
        }
        if (recent.isNotEmpty) {
          if (i < recent.length) {
            final swatch = recent[i];
            final selected = session.swatch?.id == swatch.id &&
                session.tool != PaintTool.eraser;
            return Center(
              child: _ColorWell(
                color: swatch.color,
                selected: selected,
                recent: true,
                onTap: () => session.selectSwatch(swatch),
              ),
            );
          }
          if (i == recent.length) {
            return const Center(
              child: SizedBox(
                height: 28,
                child: VerticalDivider(
                  color: Colors.white38,
                  thickness: 1,
                  width: 8,
                ),
              ),
            );
          }
          i -= recentBlock;
        }
        final swatch = swatches[i];
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

  Widget _toolAt(int index, bool showingColors) {
    // Reihenfolge: Zurück → Radierer → Undo
    if (showingColors) {
      return switch (index) {
        0 => _BackButton(session: session),
        1 => _EraserButton(session: session),
        _ => _UndoButton(session: session, onResetAll: onResetAll),
      };
    }
    return switch (index) {
      0 => _EraserButton(session: session),
      _ => _UndoButton(session: session, onResetAll: onResetAll),
    };
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.session});

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: session.openCategoryTray,
        borderRadius: radius,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.white.withValues(alpha: 0.16),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({
    required this.session,
    this.onResetAll,
  });

  final ColoringSession session;
  final VoidCallback? onResetAll;

  @override
  Widget build(BuildContext context) {
    final enabled = session.canUndo || session.canReset;
    final radius = BorderRadius.circular(14);
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: session.canUndo ? session.undo : null,
          onLongPress: session.canReset ? onResetAll : null,
          borderRadius: radius,
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.replay_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
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

/// Visuelles Paletten-Pack (wie in Kids-Apps): bunter Kreis, kurzes Label.
class _PalettePackChip extends StatelessWidget {
  const _PalettePackChip({
    required this.category,
    required this.onTap,
  });

  final PaintCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 56,
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PalettePreviewOrb(colors: category.previewColors),
                const SizedBox(height: 3),
                Text(
                  category.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PalettePreviewOrb extends StatelessWidget {
  const _PalettePreviewOrb({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: _PiePalettePainter(colors: colors),
          ),
        ),
      ),
    );
  }
}

class _PiePalettePainter extends CustomPainter {
  const _PiePalettePainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final sweep = (math.pi * 2) / colors.length;
    var start = -math.pi / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final color in colors) {
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePalettePainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class _ColorWell extends StatelessWidget {
  const _ColorWell({
    required this.color,
    required this.selected,
    required this.onTap,
    this.recent = false,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool recent;

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
          width: recent ? 44 : 50,
          height: recent ? 44 : 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? Colors.white : Colors.transparent,
            border: selected
                ? Border.all(color: const Color(0xFF121826), width: 2.8)
                : recent
                    ? Border.all(
                        color: const Color(0xFFFFE7A0).withValues(alpha: 0.7),
                        width: 1.4,
                      )
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
            width: selected ? (recent ? 32 : 38) : (recent ? 36 : 44),
            height: selected ? (recent ? 32 : 38) : (recent ? 36 : 44),
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
