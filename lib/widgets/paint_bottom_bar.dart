import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/paint_catalog.dart';
import '../data/sticker_catalog.dart';
import '../l10n/app_strings.dart';
import '../providers/coloring_session.dart';
import '../providers/coloring_sticker_placements_store.dart';
import '../providers/star_wallet_store.dart';
import '../providers/sticker_collection_store.dart';
import '../services/analytics_service.dart';
import '../services/daily_quest_service.dart';
import '../utils/app_layout.dart';
import '../utils/image_source.dart';
import 'star_balance_pill.dart';
import 'sticker_coverage_bar.dart';

/// Untere Farbleiste: Tools + Kategorien/Farben/Stickers in einer scrollbaren Reihe.
class PaintBottomBar extends StatelessWidget {
  const PaintBottomBar({
    super.key,
    required this.session,
    required this.pageId,
    this.onResetAll,
  });

  final ColoringSession session;
  final String pageId;

  /// Long-Press auf Undo → alles zurücksetzen (inkl. Progress löschen).
  final VoidCallback? onResetAll;

  static double heightOf(BuildContext context) =>
      AppLayout.of(context).paintBarHeight;

  static const stickerEntryAsset = StickerCoverageBar.stickerAsset;

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
              pageId: pageId,
              onResetAll: onResetAll,
            ),
          ),
        );
      },
    );
  }
}

/// Eine horizontale Liste: Tools | Sticker-Chip / Stickers / Kategorien / Farben.
class _ScrollablePaintTray extends StatelessWidget {
  const _ScrollablePaintTray({
    required this.session,
    required this.pageId,
    this.onResetAll,
  });

  final ColoringSession session;
  final String pageId;
  final VoidCallback? onResetAll;

  void _undo(BuildContext context) {
    final stickers = context.read<ColoringStickerPlacementsStore>();
    final stickerUndo = stickers.canUndo(pageId);
    final paintUndo = session.canUndo;
    if (stickerUndo &&
        (!paintUndo ||
            stickers.lastChangeAt(pageId).isAfter(session.lastChangeAt))) {
      unawaited(stickers.undo(pageId));
      return;
    }
    if (paintUndo) {
      session.undo();
    } else if (stickerUndo) {
      unawaited(stickers.undo(pageId));
    }
  }

  Future<void> _placeSticker(BuildContext context, String stickerId) async {
    await context.read<ColoringStickerPlacementsStore>().add(
          pageId,
          PlacedSticker(stickerId: stickerId, x: 0.5, y: 0.5),
        );
    AnalyticsService.instance.logStickerPlaced(pageId);
    if (!context.mounted) return;
    final quest = context.read<DailyQuestService>();
    final wallet = context.read<StarWalletStore>();
    await quest.markStickerPlaced(pageId);
    await quest.claimProgressRewards(wallet);
  }

  Future<void> _onStickerTap(
    BuildContext context,
    StickerEntry sticker,
    bool unlocked,
  ) async {
    if (unlocked) {
      await _placeSticker(context, sticker.id);
      return;
    }
    final wallet = context.read<StarWalletStore>();
    final store = context.read<StickerCollectionStore>();
    final cost = wallet.stickerTempCost;
    final t = AppStrings.of(context);
    final buy = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StarBalancePill.fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: StarBalancePill.border.withValues(alpha: 0.95),
          ),
        ),
        title: Text(
          t.unlockWithStarsTitle,
          style: const TextStyle(
            color: StarBalancePill.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(StarBalancePill.asset, width: 32, height: 32),
                const SizedBox(width: 8),
                Text(
                  '$cost',
                  style: const TextStyle(
                    color: StarBalancePill.ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.stickerTempUnlockHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: StarBalancePill.ink.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t.cancel,
              style: const TextStyle(color: StarBalancePill.ink),
            ),
          ),
          FilledButton(
            onPressed: wallet.balance >= cost
                ? () => Navigator.pop(ctx, true)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: StarBalancePill.border,
              foregroundColor: StarBalancePill.ink,
            ),
            child: Text(t.unlock),
          ),
        ],
      ),
    );
    if (buy != true || !context.mounted) return;
    final ok = await wallet.spendStars(cost);
    if (!ok || !context.mounted) return;
    await store.tempUnlockForPage(pageId, sticker.id);
  }

  @override
  Widget build(BuildContext context) {
    final showingColors = session.showingColors;
    final showingStickers = session.showingStickers;
    final stickersStore = context.watch<StickerCollectionStore>();
    final trayStickers = stickersStore.paintTrayStickers(pageId: pageId);
    final stickerCost = context.watch<StarWalletStore>().stickerTempCost;
    final placements = context.watch<ColoringStickerPlacementsStore>();
    final canUndo =
        session.canUndo || placements.canUndo(pageId);

    final recent = showingColors ? session.recentSwatches : const <PaintSwatch>[];
    final swatches =
        showingColors ? session.availableSwatches : const <PaintSwatch>[];
    final categories = (!showingColors && !showingStickers)
        ? PaintCatalog.categories
        : const <PaintCategory>[];

    // Tools: Zurück (Farben/Stickers) → Radierer → Undo
    final toolCount = (showingColors || showingStickers) ? 3 : 2;
    // Nach Tools: Sticker-Chip (nur Kategorien) oder Stickers oder Farben/Kats
    final stickerChip = !showingColors && !showingStickers ? 1 : 0;
    final recentBlock = recent.isEmpty ? 0 : recent.length + 1;
    final contentCount = showingStickers
        ? 1 + (trayStickers.isEmpty ? 1 : trayStickers.length) // Info + Stickers
        : showingColors
            ? recentBlock + swatches.length
            : stickerChip + categories.length;
    final itemCount = toolCount + contentCount;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: itemCount,
      separatorBuilder: (_, index) {
        if (index == toolCount - 1) {
          return const SizedBox(width: 12);
        }
        return const SizedBox(width: 8);
      },
      itemBuilder: (context, index) {
        if (index < toolCount) {
          return Center(
            child: _toolAt(
              index,
              showingColors: showingColors,
              showingStickers: showingStickers,
              canUndo: canUndo,
              onUndo: () => _undo(context),
            ),
          );
        }
        var i = index - toolCount;

        if (showingStickers) {
          if (i == 0) {
            return const Center(child: _StickerHelpButton());
          }
          i -= 1;
          if (trayStickers.isEmpty) {
            return const Center(
              child: Text(
                'No stickers yet',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            );
          }
          final sticker = trayStickers[i];
          final unlocked =
              stickersStore.canPlaceInColoring(sticker.id, pageId: pageId);
          return Center(
            child: _TrayStickerChip(
              sticker: sticker,
              locked: !unlocked,
              lockCost: stickerCost,
              onTap: () => unawaited(
                _onStickerTap(context, sticker, unlocked),
              ),
            ),
          );
        }

        if (!showingColors) {
          if (i == 0) {
            return Center(
              child: _StickerEntryChip(
                selected: false,
                onTap: session.openStickerTray,
              ),
            );
          }
          final category = categories[i - 1];
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

  Widget _toolAt(
    int index, {
    required bool showingColors,
    required bool showingStickers,
    required bool canUndo,
    required VoidCallback onUndo,
  }) {
    if (showingColors || showingStickers) {
      return switch (index) {
        0 => _BackButton(session: session),
        1 => _EraserButton(session: session),
        _ => _UndoButton(
            enabled: canUndo,
            canReset: session.canReset,
            onUndo: onUndo,
            onResetAll: onResetAll,
          ),
      };
    }
    return switch (index) {
      0 => _EraserButton(session: session),
      _ => _UndoButton(
          enabled: canUndo,
          canReset: session.canReset,
          onUndo: onUndo,
          onResetAll: onResetAll,
        ),
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
    required this.enabled,
    required this.canReset,
    required this.onUndo,
    this.onResetAll,
  });

  final bool enabled;
  final bool canReset;
  final VoidCallback onUndo;
  final VoidCallback? onResetAll;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Opacity(
      opacity: enabled || canReset ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onUndo : null,
          onLongPress: canReset ? onResetAll : null,
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

class _StickerEntryChip extends StatelessWidget {
  const _StickerEntryChip({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Stickers',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: selected ? 1 : 0.95,
            child: Image.asset(
              PaintBottomBar.stickerEntryAsset,
              width: 58,
              height: 58,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

class _StickerHelpButton extends StatelessWidget {
  const _StickerHelpButton();

  void _showHelp(BuildContext context) {
    final t = AppStrings.of(context);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF3E6C8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            t.stickerPlaceHelpTitle,
            style: const TextStyle(
              color: Color(0xFF4A3208),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            t.stickerPlaceHelpBody,
            style: const TextStyle(
              color: Color(0xFF4A3208),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                t.letsGo,
                style: const TextStyle(
                  color: Color(0xFF4A3208),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      label: 'Sticker help',
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showHelp(context),
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
              Icons.info_outline_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrayStickerChip extends StatelessWidget {
  const _TrayStickerChip({
    required this.sticker,
    required this.onTap,
    this.locked = false,
    this.lockCost = 15,
  });

  final StickerEntry sticker;
  final VoidCallback onTap;
  final bool locked;
  final int lockCost;

  @override
  Widget build(BuildContext context) {
    final image = isLocalImageAvailable(sticker.assetPath)
        ? Image(
            image: imageProviderFor(sticker.assetPath),
            width: 58,
            height: 58,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          )
        : const Icon(Icons.sticky_note_2, color: Colors.white70, size: 40);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: locked ? 0.45 : 1,
                  child: image,
                ),
              ),
              if (locked)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2A40).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFFD56A).withValues(alpha: 0.9),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            StarBalancePill.asset,
                            width: 14,
                            height: 14,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$lockCost',
                            style: const TextStyle(
                              color: Color(0xFFFFF4C8),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PalettePreviewOrb(colors: category.previewColors),
                  const SizedBox(height: 2),
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _PalettePreviewOrb extends StatelessWidget {
  const _PalettePreviewOrb({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [
          for (final c in colors) c,
          if (colors.isNotEmpty) colors.first,
        ]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
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
  final bool recent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outer = recent ? 44.0 : 50.0;
    final inner = selected ? (recent ? 32.0 : 38.0) : (recent ? 36.0 : 44.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: outer,
          height: outer,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selected)
                Container(
                  width: outer,
                  height: outer,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF121826), width: 2.8),
                  ),
                ),
              Container(
                width: inner,
                height: inner,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: selected ? 0.95 : 0.55),
                    width: selected ? 2.4 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
