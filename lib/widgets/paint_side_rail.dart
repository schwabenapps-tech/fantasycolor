import 'package:flutter/material.dart';

import '../data/paint_catalog.dart';
import '../providers/coloring_session.dart';

/// Rechte Seitenleiste: Farben (scrollbar) | Kategorien ganz rechts.
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
          width: 148,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(20)),
            border: Border.all(color: Colors.white24),
          ),
          child: SafeArea(
            left: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
              child: Column(
                children: [
                  _ToolRow(session: session),
                  if (session.tool == PaintTool.pen) ...[
                    const SizedBox(height: 6),
                    _PenSizeRow(session: session),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ColorList(session: session)),
                        const SizedBox(width: 6),
                        _CategoryColumn(session: session),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryColumn extends StatelessWidget {
  const _CategoryColumn({required this.session});

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: ListView.separated(
        itemCount: PaintCatalog.categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final category = PaintCatalog.categories[index];
          final selected = session.category == category;
          return _CategoryChip(
            category: category,
            selected: selected,
            onTap: () => session.selectCategory(category),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final PaintCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      category.accent,
                      Color.lerp(
                        category.accent,
                        const Color(0xFF1C2742),
                        0.35,
                      )!,
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.08),
                    ],
            ),
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: category.accent.withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            category.icon,
            color: Colors.white,
            size: selected ? 24 : 20,
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.16),
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

class _PenSizeRow extends StatelessWidget {
  const _PenSizeRow({required this.session});

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final size in PenSize.values) ...[
          Expanded(
            child: _PenSizeButton(
              size: size,
              selected: session.penSize == size,
              onTap: () => session.selectPenSize(size),
            ),
          ),
          if (size != PenSize.thick) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _PenSizeButton extends StatelessWidget {
  const _PenSizeButton({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final PenSize size;
  final bool selected;
  final VoidCallback onTap;

  double get _dot => switch (size) {
        PenSize.thin => 6,
        PenSize.medium => 11,
        PenSize.thick => 16,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? const Color(0xFFE9D7FF).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.14),
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Center(
            child: Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? const Color(0xFF6B4FA0)
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorList extends StatelessWidget {
  const _ColorList({required this.session});

  final ColoringSession session;

  @override
  Widget build(BuildContext context) {
    final category = session.category;
    if (category == null) return const SizedBox.shrink();
    final swatches = session.availableSwatches;

    return ListView.separated(
      itemCount: swatches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final swatch = swatches[index];
        final selected = session.swatch?.id == swatch.id &&
            session.tool != PaintTool.eraser;
        return Center(
          child: _ColorWell(
            color: swatch.color,
            selected: selected,
            category: category,
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
        customBorder: const CircleBorder(),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected ? Colors.white : Colors.white38,
              width: selected ? 3.2 : 1.4,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: color.withValues(alpha: 0.75),
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
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
            gradient: category == PaintCategory.glitter
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.9),
                      color,
                      Color.lerp(color, Colors.black, 0.12)!,
                    ],
                  )
                : category == PaintCategory.watercolor
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.8),
                          color,
                        ],
                      )
                    : null,
          ),
          child: category == PaintCategory.glitter
              ? const Center(
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.white70,
                    size: 16,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
