import 'package:flutter/material.dart';

import '../data/paint_catalog.dart';
import '../l10n/app_strings.dart';
import '../utils/app_layout.dart';

/// Rechte Farbleiste für Pixel-/Malen-nach-Zahlen.
///
/// Optik wie die Mal-Leiste (runde Wells), aber nur die nummerierten
/// Bildfarben — keine festen Katalog-Paletten.
class PixelPaintRail extends StatelessWidget {
  const PixelPaintRail({
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

  static double widthOf(BuildContext context) =>
      AppLayout.of(context).paintRailWidth;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final railWidth = widthOf(context);
    final hasOpenColors = swatches.any((s) {
      final n = s.number ?? 0;
      return n > 0 && remainingOf(n) > 0;
    });
    return Container(
      width: railWidth,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
        border: Border.all(color: Colors.white24),
      ),
      child: SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
          child: Column(
            children: [
              Text(
                t.imageColors,
                style: const TextStyle(
                  color: Color(0xFFFFE7A0),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t.pickNumber,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: swatches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final swatch = swatches[index];
                    final number = swatch.number ?? (index + 1);
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
              if (onHelpWithAd != null && hasOpenColors) ...[
                const SizedBox(height: 8),
                _FillNumberAdButton(
                  busy: fillAdBusy,
                  fillsLeft: adFillsLeft,
                  onPressed: onHelpWithAd!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FillNumberAdButton extends StatelessWidget {
  const _FillNumberAdButton({
    required this.busy,
    required this.fillsLeft,
    required this.onPressed,
  });

  final bool busy;
  final int fillsLeft;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final enabled = fillsLeft > 0 && !busy;
    return Tooltip(
      message: fillsLeft > 0
          ? t.pixelFillNumberAdHint
          : t.pixelAdFillsExhausted,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : (fillsLeft <= 0 ? onPressed : null),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFFFD56A).withValues(alpha: 0.18),
                border: Border.all(
                  color: const Color(0xFFFFD56A).withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      size: 20,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    t.pixelFillNumberAd,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFE7A0),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    fillsLeft > 0
                        ? t.pixelAdFillsLeft(fillsLeft)
                        : '0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
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
          width: 44,
          height: 44,
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
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
