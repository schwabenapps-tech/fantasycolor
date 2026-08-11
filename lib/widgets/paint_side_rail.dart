import 'package:flutter/material.dart';

import '../data/paint_catalog.dart';
import '../providers/coloring_session.dart';

/// Rechte Seitenleiste: Kategorien → Werkzeuge + große Farbfelder.
class PaintSideRail extends StatelessWidget {
  const PaintSideRail({
    super.key,
    required this.session,
  });

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return Container(
          width: 118,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            border: Border.all(color: Colors.white24),
          ),
          child: SafeArea(
            left: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: session.hasCategory
                  ? _PalettePane(session: session)
                  : _CategoryPane(session: session),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryPane extends StatelessWidget {
  const _CategoryPane({required this.session});

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Farben',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: PaintCatalog.categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final category = PaintCatalog.categories[index];
              return _CategoryButton(
                category: category,
                onTap: () => session.selectCategory(category),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.category,
    required this.onTap,
  });

  final PaintCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                category.accent.withValues(alpha: 0.95),
                category.accent.withValues(alpha: 0.55),
                const Color(0xFF1C2742),
              ],
            ),
            border: Border.all(color: Colors.white30),
            boxShadow: [
              BoxShadow(
                color: category.accent.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                category.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalettePane extends StatelessWidget {
  const _PalettePane({required this.session});

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    final category = session.category!;
    final swatches = session.availableSwatches;

    return Column(
      children: [
        Row(
          children: [
            InkWell(
              onTap: session.clearCategory,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
            Expanded(
              child: Text(
                category.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ToolRow(session: session),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: swatches.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final swatch = swatches[index];
              final selected = session.swatch?.id == swatch.id &&
                  session.tool != PaintTool.eraser;
              return _ColorWell(
                color: swatch.color,
                selected: selected,
                category: category,
                onTap: () => session.selectSwatch(swatch),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.session});

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tool in PaintTool.values) ...[
          Expanded(
            child: _ToolButton(
              tool: tool,
              selected: session.tool == tool,
              onTap: () => session.selectTool(tool),
            ),
          ),
          if (tool != PaintTool.eraser) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  final PaintTool tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? Colors.white.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.18),
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Icon(
            tool.icon,
            size: 20,
            color: selected ? const Color(0xFF243044) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ColorWell extends StatelessWidget {
  const _ColorWell({
    required this.color,
    required this.selected,
    required this.category,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final PaintCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color,
            border: Border.all(
              color: selected ? Colors.white : Colors.white30,
              width: selected ? 3 : 1.2,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: color.withValues(alpha: 0.7),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              if (category == PaintCategory.glow)
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
            gradient: category == PaintCategory.glitter
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.85),
                      color,
                      Color.lerp(color, Colors.black, 0.15)!,
                    ],
                  )
                : category == PaintCategory.watercolor
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.75),
                          color,
                        ],
                      )
                    : null,
          ),
          child: category == PaintCategory.glitter
              ? const Center(
                  child: Icon(Icons.auto_awesome, color: Colors.white70, size: 18),
                )
              : null,
        ),
      ),
    );
  }
}
