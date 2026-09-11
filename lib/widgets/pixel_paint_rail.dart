import 'package:flutter/material.dart';

import '../data/paint_catalog.dart';
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
  });

  final List<PaintSwatch> swatches;
  final int selectedNumber;
  final int Function(int number) remainingOf;
  final ValueChanged<int> onSelect;

  static double widthOf(BuildContext context) =>
      AppLayout.of(context).paintRailWidth;

  @override
  Widget build(BuildContext context) {
    final railWidth = widthOf(context);
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
              const Text(
                'Bildfarben',
                style: TextStyle(
                  color: Color(0xFFFFE7A0),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Nummer wählen',
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
            ],
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
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 54,
          height: 54,
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
            width: selected ? 40 : 48,
            height: selected ? 40 : 48,
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
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
