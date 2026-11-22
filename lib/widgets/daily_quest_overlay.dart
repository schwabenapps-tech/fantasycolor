import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../data/puzzle_images_loader.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../models/pixel_puzzle.dart';
import '../models/puzzle_settings.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/coloring_sticker_placements_store.dart';
import '../providers/pixel_progress_store.dart';
import '../providers/sticker_collection_store.dart';
import '../screens/coloring_preview_screen.dart';
import '../screens/pixel_paint_screen.dart';
import '../screens/puzzle_screen.dart';
import '../services/daily_quest_service.dart';
import '../utils/app_page_route.dart';
import 'coloring_page_image.dart';
import 'daily_quest_pill.dart';
import 'puzzle_preview_overlay.dart';
import 'star_balance_pill.dart';

class DailyQuestOverlay {
  DailyQuestOverlay._();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const _DailyQuestDialog(),
    );
  }
}

class _DailyQuestDialog extends StatefulWidget {
  const _DailyQuestDialog();

  @override
  State<_DailyQuestDialog> createState() => _DailyQuestDialogState();
}

class _DailyQuestDialogState extends State<_DailyQuestDialog> {
  late final Future<Map<String, ColoringPage>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = _loadPages();
  }

  Future<Map<String, ColoringPage>> _loadPages() async {
    final coloring = await loadColoringPages(shuffle: false);
    final puzzles = await loadPuzzleImages(shuffle: false);
    return {
      for (final p in coloring) p.id: p,
      for (final p in puzzles) p.id: p,
    };
  }

  Future<void> _openTask(DailyQuestTask task, ColoringPage? page) async {
    if (page == null) return;
    // Root-Navigator behalten — nach Dialog-pop ist dieser State disposed.
    final nav = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop(); // Daily-Dialog zu
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final ctx = nav.context;
    if (!ctx.mounted) return;

    if (task.isColoring || task.isPlaceSticker || task.isRecolor) {
      if (task.isRecolor) {
        // Fertiges Bild zurücksetzen und neu ausmalen.
        final progress = ctx.read<ColoringProgressStore>();
        final stickers = ctx.read<StickerCollectionStore>();
        final placements = ctx.read<ColoringStickerPlacementsStore>();
        await progress.clearProgress(page.id);
        await stickers.clearColoringRewarded(page.id);
        await placements.setPlacements(page.id, const []);
        if (!ctx.mounted) return;
      }
      await nav.push(
        AppPageRoute<void>(
          builder: (_) => ColoringPreviewScreen(page: page),
        ),
      );
      return;
    }

    if (task.isPixel) {
      final progress = ctx.read<ColoringProgressStore>();
      final pixelStore = ctx.read<PixelProgressStore>();
      final colored = await progress.loadProgressBytes(page.id);
      final existing = await pixelStore.loadSnapshot(page.id);
      // Schon fertig bemalt → für Daily von vorn (Bilder wiederverwendbar).
      if (existing != null && existing.completed) {
        await pixelStore.clearProgress(page.id);
      }
      if (!ctx.mounted) return;
      final resume = existing != null && !existing.completed ? existing : null;
      await nav.push(
        AppPageRoute<void>(
          builder: (_) => PixelPaintScreen(
            page: page,
            difficulty: PixelDifficulty.standard,
            resumeSnapshot: resume,
            sourceBytes: colored,
          ),
        ),
      );
      return;
    }

    final challenge =
        task.puzzleRequirement == DailyQuestPuzzleRequirement.mediumOrHard;
    final choice = await PuzzlePreviewOverlay.show(
      ctx,
      page,
      lockedTiers: challenge ? {PuzzleTier.easy} : const {},
      lockedDifficulties:
          challenge ? {PuzzleDifficulty.medium30} : const {},
      initialDifficulty:
          challenge ? PuzzleDifficulty.medium42 : null,
    );
    if (choice == null || !ctx.mounted) return;

    await nav.push(
      AppPageRoute<void>(
        builder: (_) => PuzzleScreen(
          puzzle: page,
          initialDifficulty: choice.difficulty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final quest = context.watch<DailyQuestService>();

    return AlertDialog(
      backgroundColor: StarBalancePill.fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: StarBalancePill.border.withValues(alpha: 0.95),
        ),
      ),
      title: Row(
        children: [
          Image.asset(DailyQuestPill.asset, width: 36, height: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.dailyQuest,
              style: const TextStyle(
                color: StarBalancePill.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: FutureBuilder<Map<String, ColoringPage>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          final byId = snapshot.data ?? const <String, ColoringPage>{};
          if (quest.tasks.isEmpty) {
            return Text(
              '—',
              style: TextStyle(
                color: StarBalancePill.ink.withValues(alpha: 0.7),
              ),
            );
          }
          final maxH = MediaQuery.sizeOf(context).height * 0.55;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: double.maxFinite,
              maxHeight: maxH,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.dailyQuestIncentive,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: StarBalancePill.ink.withValues(alpha: 0.95),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < quest.tasks.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _TaskCard(
                      task: quest.tasks[i],
                      page: byId[quest.tasks[i].pageId],
                      done: quest.isTaskDone(quest.tasks[i]),
                      loading: !snapshot.hasData,
                      onTap: () => _openTask(
                        quest.tasks[i],
                        byId[quest.tasks[i].pageId],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t.streakQuestClose,
            style: const TextStyle(color: StarBalancePill.ink),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.page,
    required this.done,
    required this.loading,
    required this.onTap,
  });

  final DailyQuestTask task;
  final ColoringPage? page;
  final bool done;
  final bool loading;
  final VoidCallback onTap;

  String _brief(AppStrings t) {
    if (task.isPlaceSticker) return t.dailyTaskPlaceSticker;
    if (task.isPixel) return t.dailyTaskPixel;
    if (task.isRecolor) return t.dailyTaskRecolor;
    if (task.isColoring) return t.dailyTaskColor;
    if (task.puzzleRequirement == DailyQuestPuzzleRequirement.mediumOrHard) {
      return t.dailyTaskPuzzleHard;
    }
    return t.dailyTaskPuzzleAny;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: done ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done
                  ? const Color(0xFF3DBE7A).withValues(alpha: 0.75)
                  : StarBalancePill.border.withValues(alpha: 0.65),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.92),
                      child: loading
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : page == null
                              ? Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.black.withValues(alpha: 0.35),
                                )
                              : Opacity(
                                  opacity: done ? 0.55 : 1,
                                  child: ColoringPageImage(
                                    page: page!,
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _brief(t),
                    style: TextStyle(
                      color: StarBalancePill.ink.withValues(alpha: 0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  done ? Icons.check_circle : Icons.chevron_right_rounded,
                  color: done
                      ? const Color(0xFF2E9E64)
                      : StarBalancePill.ink.withValues(alpha: 0.85),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
