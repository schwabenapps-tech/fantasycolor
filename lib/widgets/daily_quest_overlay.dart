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
import '../providers/favorites_store.dart';
import '../providers/pixel_progress_store.dart';
import '../providers/star_wallet_store.dart';
import '../providers/sticker_collection_store.dart';
import '../screens/advent_calendar_screen.dart';
import '../screens/coloring_preview_screen.dart';
import '../screens/pixel_paint_screen.dart';
import '../screens/puzzle_screen.dart';
import '../services/daily_quest_service.dart';
import '../utils/app_page_route.dart';
import 'coloring_page_image.dart';
import 'daily_quest_pill.dart';
import 'earn_stars_sheet.dart';
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
    if (task.isUnlockChoice) {
      await _completeUnlockChoice(task);
      return;
    }
    if (task.isWatchAd) {
      final nav = Navigator.of(context, rootNavigator: true);
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final ctx = nav.context;
      if (!ctx.mounted) return;
      await EarnStarsSheet.show(ctx);
      return;
    }
    if (task.isAdventDoor) {
      final nav = Navigator.of(context, rootNavigator: true);
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final ctx = nav.context;
      if (!ctx.mounted) return;
      await nav.push(
        AppPageRoute<void>(builder: (_) => const AdventCalendarScreen()),
      );
      return;
    }
    if (page == null) return;
    // Root-Navigator behalten — nach Dialog-pop ist dieser State disposed.
    final nav = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop(); // Daily-Dialog zu
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final ctx = nav.context;
    if (!ctx.mounted) return;

    if (task.isColoring ||
        task.isPlaceSticker ||
        task.isRecolor ||
        task.isColoringThreeStar ||
        task.isEventFinish) {
      await nav.push(
        AppPageRoute<void>(
          builder: (_) => ColoringPreviewScreen(
            page: page,
            // Recolor: Farben-Zurückzieh-Animation, dann blanke Vorlage.
            recycleReset: task.isRecolor,
          ),
        ),
      );
      return;
    }

    if (task.isPixel || task.isPixelThreeStar) {
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

    final req = task.puzzleRequirement;
    // Daily nennt genau eine Stufe: Easy / Medium / Schwer.
    final lockedTiers = switch (req) {
      DailyQuestPuzzleRequirement.any => {
          PuzzleTier.medium,
          PuzzleTier.expert,
        },
      DailyQuestPuzzleRequirement.mediumOrHard => {
          PuzzleTier.easy,
          PuzzleTier.expert,
        },
      DailyQuestPuzzleRequirement.hardOnly => {
          PuzzleTier.easy,
          PuzzleTier.medium,
        },
    };
    final lockedDifficulties = switch (req) {
      DailyQuestPuzzleRequirement.any => {
          PuzzleDifficulty.medium30,
          PuzzleDifficulty.medium42,
          PuzzleDifficulty.medium64,
          PuzzleDifficulty.expert80,
          PuzzleDifficulty.expert100,
          PuzzleDifficulty.expert120,
        },
      DailyQuestPuzzleRequirement.mediumOrHard => {
          PuzzleDifficulty.expert80,
          PuzzleDifficulty.expert100,
          PuzzleDifficulty.expert120,
        },
      DailyQuestPuzzleRequirement.hardOnly => {
          PuzzleDifficulty.medium30,
          PuzzleDifficulty.medium42,
          PuzzleDifficulty.medium64,
        },
    };
    final initial = switch (req) {
      DailyQuestPuzzleRequirement.any => PuzzleDifficulty.easy12,
      DailyQuestPuzzleRequirement.mediumOrHard => PuzzleDifficulty.medium42,
      DailyQuestPuzzleRequirement.hardOnly => PuzzleDifficulty.expert80,
    };
    final choice = await PuzzlePreviewOverlay.show(
      ctx,
      page,
      lockedTiers: lockedTiers,
      lockedDifficulties: lockedDifficulties,
      initialDifficulty: initial,
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

  Future<void> _completeUnlockChoice(DailyQuestTask task) async {
    final t = AppStrings.of(context);
    final wallet = context.read<StarWalletStore>();
    final quest = context.read<DailyQuestService>();
    final coloring = await loadColoringPages(shuffle: false);
    final puzzles = await loadPuzzleImages(shuffle: false);
    if (!mounted) return;

    final locked = <({ColoringPage page, FavoriteKind kind})>[
      for (final page in coloring)
        if (wallet.requiresStars(page.id, FavoriteKind.coloring))
          (page: page, kind: FavoriteKind.coloring),
      for (final page in puzzles)
        if (wallet.requiresStars(page.id, FavoriteKind.puzzle))
          (page: page, kind: FavoriteKind.puzzle),
    ];

    if (locked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.dailyUnlockEmpty)),
      );
      await quest.markUnlockChoiceDone();
      await quest.claimProgressRewards(wallet);
      return;
    }

    final picked = await showDialog<({ColoringPage page, FavoriteKind kind})>(
      context: context,
      builder: (ctx) => _DailyUnlockPickerDialog(items: locked),
    );
    if (picked == null || !mounted) return;

    await wallet.grantUnlock(picked.page.id, picked.kind);
    await quest.markUnlockChoiceDone();
    await quest.claimProgressRewards(wallet);
    if (!mounted) return;

    // Daily zu, dann freigeschaltetes Motiv direkt öffnen.
    final nav = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop(); // Daily-Dialog
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final ctx = nav.context;
    if (!ctx.mounted) return;

    if (picked.kind == FavoriteKind.coloring) {
      await nav.push(
        AppPageRoute<void>(
          builder: (_) => ColoringPreviewScreen(page: picked.page),
        ),
      );
      return;
    }

    final choice = await PuzzlePreviewOverlay.show(ctx, picked.page);
    if (choice == null || !ctx.mounted) return;
    await nav.push(
      AppPageRoute<void>(
        builder: (_) => PuzzleScreen(
          puzzle: picked.page,
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
    if (task.isPixelThreeStar) return t.dailyTaskPixelThreeStar;
    if (task.isPixel) return t.dailyTaskPixel;
    if (task.isRecolor) return t.dailyTaskRecolor;
    if (task.isUnlockChoice) return t.dailyTaskUnlockChoice;
    if (task.isWatchAd) return t.dailyTaskWatchAd;
    if (task.isColoringThreeStar) return t.dailyTaskColorThreeStar;
    if (task.isEventFinish) return t.dailyTaskEventFinish;
    if (task.isAdventDoor) return t.dailyTaskAdventDoor;
    if (task.isColoring) return t.dailyTaskColor;
    if (task.isPuzzle) {
      return switch (task.puzzleRequirement) {
        DailyQuestPuzzleRequirement.hardOnly => t.dailyTaskPuzzleExpert,
        DailyQuestPuzzleRequirement.mediumOrHard => t.dailyTaskPuzzleHard,
        DailyQuestPuzzleRequirement.any => t.dailyTaskPuzzleAny,
      };
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
                          : task.isUnlockChoice
                              ? Icon(
                                  Icons.lock_open_rounded,
                                  color: StarBalancePill.ink
                                      .withValues(alpha: 0.75),
                                  size: 30,
                                )
                              : task.isWatchAd
                                  ? Image.asset(
                                      EarnStarsSheet.videoStarAsset,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.contain,
                                    )
                                  : task.isAdventDoor
                                      ? Icon(
                                          Icons.card_giftcard_rounded,
                                          color: StarBalancePill.ink
                                              .withValues(alpha: 0.75),
                                          size: 30,
                                        )
                                      : page == null
                                          ? Icon(
                                              Icons.image_not_supported_outlined,
                                              color: Colors.black
                                                  .withValues(alpha: 0.35),
                                            )
                                          : Opacity(
                                              opacity: done ? 0.55 : 1,
                                              child: ColoringPageImage(
                                                page: page!,
                                                fit: BoxFit.cover,
                                                borderRadius:
                                                    BorderRadius.circular(10),
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

class _DailyUnlockPickerDialog extends StatelessWidget {
  const _DailyUnlockPickerDialog({required this.items});

  final List<({ColoringPage page, FavoriteKind kind})> items;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.55;
    return AlertDialog(
      backgroundColor: StarBalancePill.fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: StarBalancePill.border.withValues(alpha: 0.95),
        ),
      ),
      title: Text(
        t.dailyUnlockPickTitle,
        style: const TextStyle(
          color: StarBalancePill.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: maxH,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isPuzzle = item.kind == FavoriteKind.puzzle;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context, item),
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: StarBalancePill.border.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ColoringPageImage(
                              page: item.page,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPuzzle ? t.puzzle : t.color,
                          style: TextStyle(
                            color: StarBalancePill.ink.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            t.cancel,
            style: const TextStyle(color: StarBalancePill.ink),
          ),
        ),
      ],
    );
  }
}
