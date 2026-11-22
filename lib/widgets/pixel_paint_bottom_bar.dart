import 'package:flutter/material.dart';

import '../data/paint_catalog.dart';
import '../l10n/app_strings.dart';
import '../utils/app_layout.dart';

/// Untere Farbleiste für Pixel-/Malen-nach-Zahlen (wie PaintBottomBar).
///
/// Glühbirne (Ad-Hilfe) zuerst, danach nummerierte Bildfarben — horizontal.
class PixelPaintBottomBar extends StatelessWidget {
  const PixelPaintBottomBar({
    super.key,
    required this.swatches,
    required this.selectedNumber,
    required this.remainingOf,
    required this.onSelect,
    this.onHelpWithAd,
    this.fillAdBusy = false,
    this.adFillsLeft = 0,
  });

  final List<PaintSwatch> swatches;
  final int selectedNumber;
  final int Function(int number) remainingOf;
  final ValueChanged<int> onSelect;
  final VoidCallback? onHelpWithAd;
  final bool fillAdBusy;
  final int adFillsLeft;

  static double heightOf(BuildContext context) =>
      AppLayout.of(context).paintBarHeight;

  @override
  Widget build(BuildContext context) {
    final barHeight = heightOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hasOpenColors = swatches.any((s) {
      final n = s.number ?? 0;
      return n > 0 && remainingOf(n) > 0;
    });
    final showBulb = onHelpWithAd != null;

    // Glühbirne + Farben.
    final itemCount = (showBulb ? 1 : 0) + swatches.length;

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
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            if (showBulb && index == 0) {
              return Center(
                child: _FillNumberAdChip(
                  busy: fillAdBusy,
                  fillsLeft: adFillsLeft,
                  hasOpenColors: hasOpenColors,
                  onPressed: onHelpWithAd!,
                ),
              );
            }
            final swatchIndex = showBulb ? index - 1 : index;
            final swatch = swatches[swatchIndex];
            final number = swatch.number ?? (swatchIndex + 1);
            final selected = number == selectedNumber;
            final left = remainingOf(number);
            final done = left == 0;
            return Center(
              child: Opacity(
                opacity: done ? 0.32 : 1,
                child: _NumberedColorWell(
                  color: swatch.color,
                  number: number,
                  selected: selected,
                  enabled: !done,
                  onTap: () => onSelect(number),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FillNumberAdChip extends StatelessWidget {
  const _FillNumberAdChip({
    required this.busy,
    required this.fillsLeft,
    required this.hasOpenColors,
    required this.onPressed,
  });

  final bool busy;
  final int fillsLeft;
  final bool hasOpenColors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final enabled = fillsLeft > 0 && hasOpenColors && !busy;
    return Tooltip(
      message: fillsLeft > 0
          ? t.pixelFillNumberAdHint
          : t.pixelAdFillsExhausted,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy ? null : onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFFFD56A).withValues(alpha: 0.18),
                border: Border.all(
                  color: const Color(0xFFFFD56A).withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFFE7A0),
                      ),
                    )
                  else
                    const Icon(
                      Icons.lightbulb_rounded,
                      color: Color(0xFFFFE7A0),
                      size: 26,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    fillsLeft > 0 ? t.pixelAdFillsLeft(fillsLeft) : '0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberedColorWell extends StatelessWidget {
  const _NumberedColorWell({
    required this.color,
    required this.number,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Color color;
  final int number;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = color.computeLuminance() > 0.45
        ? const Color(0xFF1A1F2C)
        : Colors.white;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected ? const Color(0xFFFFE7A0) : Colors.white54,
              width: selected ? 3 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD56A).withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ),
      ),
    );
  }
}
