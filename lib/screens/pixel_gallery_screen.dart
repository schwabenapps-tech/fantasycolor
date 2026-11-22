import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../models/pixel_puzzle.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/pixel_mode_unlock_store.dart';
import '../providers/pixel_progress_store.dart';
import '../providers/pixel_ready_store.dart';
import '../providers/star_wallet_store.dart';
import '../services/ads_service.dart';
import '../services/daily_quest_service.dart';
import '../utils/app_layout.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/progress_badge.dart';
import '../widgets/silver_back_button.dart';
import 'pixel_paint_screen.dart';
import '../utils/app_page_route.dart';

/// Pixelart nur für fertige Ausmalbilder.
class PixelGalleryScreen extends StatefulWidget {
  const PixelGalleryScreen({super.key, this.embedded = false});

  /// Im Hub-Tab: kein eigener Scaffold / Back-Button.
  final bool embedded;

  static const backgroundAsset = 'assets/images/in_app_background.png';

  @override
  State<PixelGalleryScreen> createState() => _PixelGalleryScreenState();
}

class _PixelGalleryScreenState extends State<PixelGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Future<List<ColoringPage>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = loadColoringPages(shuffle: false);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncReadyFromExisting());
    });
  }

  Future<void> _syncReadyFromExisting() async {
    if (!mounted) return;
    final progress = context.read<ColoringProgressStore>();
    final wallet = context.read<StarWalletStore>();
    final ready = context.read<PixelReadyStore>();
    final quest = context.read<DailyQuestService>();
    if (!progress.isReady) await progress.load();
    if (!wallet.isReady) await wallet.load();
    if (!ready.isReady) await ready.load();
    await ready.syncFromCompletedColoring(
      progressIds: progress.progressIds,
      coloringRating: wallet.coloringRating,
      extraIds: [
        for (final t in quest.tasks)
          if ((t.isColoring || t.isRecolor) && quest.isTaskDone(t)) t.pageId,
      ],
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _openPage(ColoringPage page) async {
    HapticFeedback.selectionClick();
    final readyStore = context.read<PixelReadyStore>();
    final store = context.read<PixelProgressStore>();
    final coloringProgress = context.read<ColoringProgressStore>();
    if (!readyStore.isPaintUnlocked(page.id)) {
      await AdsService.showEventContentUnlockInterstitial();
      if (!mounted) return;
      await readyStore.unlockPaint(page.id);
    }
    if (!mounted) return;

    final existing = await store.loadSnapshot(page.id);
    final sourceBytes = await coloringProgress.loadProgressBytes(page.id);

    if (!mounted) return;

    PixelProgressSnapshot? resume;
    if (existing != null && !existing.completed && existing.filledCount > 0) {
      resume = existing;
    } else if (existing != null) {
      await store.clearProgress(page.id);
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PixelPaintScreen(
          page: page,
          difficulty: PixelDifficulty.standard,
          sourceBytes: sourceBytes,
          resumeSnapshot: resume,
        ),
      ),
    );
  }

  Widget _galleryBody(BuildContext context) {
    final t = AppStrings.of(context);
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final tileHeight = layout.galleryTileHeight;
    final tileWidth = layout.galleryTileWidth;
    final ready = context.watch<PixelReadyStore>();
    final topPad = widget.embedded
        ? layout.galleryTopSpacer * 0.25
        : layout.galleryTopSpacer * 0.55;

    return FutureBuilder<List<ColoringPage>>(
      future: _pagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Color(0xFFE8EEF8),
              ),
            ),
          );
        }

        final all = snapshot.data ?? const <ColoringPage>[];
        final pages = [
          for (final p in all)
            if (ready.isReadyFor(p.id)) p,
        ];
        if (pages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                t.pixelArtEmpty,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            SizedBox(height: topPad),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
              child: Text(
                t.pixelArt,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFE7A0),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.pixelArtHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
            Expanded(
              child: Align(
                alignment: const Alignment(0, 0.35),
                child: SizedBox(
                  height: tileHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.055,
                    ),
                    itemCount: pages.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(width: size.width * 0.03),
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      final pixelProgress =
                          context.watch<PixelProgressStore>();
                      return _PixelPageTile(
                        page: page,
                        width: tileWidth,
                        height: tileHeight,
                        hasProgress: pixelProgress.hasProgress(page.id),
                        isCompleted: pixelProgress.isCompleted(page.id),
                        requiresAdUnlock: !ready.isPaintUnlocked(page.id),
                        onTap: () => _openPage(page),
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: size.height * 0.03),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = FadeTransition(
      opacity: _fadeAnimation,
      child: _galleryBody(context),
    );

    if (widget.embedded) return body;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            PixelGalleryScreen.backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: Stack(
              children: [
                body,
                Positioned(
                  top: 10,
                  left: 12,
                  child: SilverBackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nur Freischaltung (Interstitial), ohne Navigation.
Future<void> openPixelModeUnlockOnly(BuildContext context) async {
  final unlock = context.read<PixelModeUnlockStore>();
  if (unlock.isUnlocked) return;
  await AdsService.showInterstitial();
  await unlock.unlock();
}

/// Einstieg aus dem Color-Hub — Bilder einzeln per Werbung freischalten.
Future<void> openPixelModeFromGallery(BuildContext context) async {
  await Navigator.of(context).push(
    AppPageRoute<void>(
      builder: (_) => const PixelGalleryScreen(),
    ),
  );
}

Future<bool?> showPixelUnlockDialog(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Unlock',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, anim, secondary) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.7,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2B3B66),
                        Color(0xFF1A2744),
                        Color(0xFF121C33),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFD56A).withValues(alpha: 0.55),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD56A).withValues(alpha: 0.2),
                        blurRadius: 28,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.grid_on_rounded,
                          color: Color(0xFFFFD56A),
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Advanced mode',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFFE7A0),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Paint by numbers with pixel art.\n'
                          'Watch a short ad to unlock this mode.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _PixelDialogButton(
                                label: 'Later',
                                filled: false,
                                onPressed: () => Navigator.pop(context, false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PixelDialogButton(
                                label: 'Unlock',
                                filled: true,
                                onPressed: () => Navigator.pop(context, true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PixelPageTile extends StatelessWidget {
  const _PixelPageTile({
    required this.page,
    required this.width,
    required this.height,
    required this.hasProgress,
    required this.isCompleted,
    required this.onTap,
    this.requiresAdUnlock = false,
  });

  final ColoringPage page;
  final double width;
  final double height;
  final bool hasProgress;
  final bool isCompleted;
  final VoidCallback onTap;
  final bool requiresAdUnlock;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF8E8),
                Color(0xFFFFE0A0),
                Color(0xFFE8B86A),
                Color(0xFFFFF0C8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD56A).withValues(alpha: 0.3),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: Colors.white,
                      // Immer das Ausmalbild — nie den Pixel-Zwischenstand.
                      child: ColoringPageImage(
                        page: page,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (hasProgress)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: ProgressBadge(
                      label: isCompleted ? 'Done' : 'Continue',
                      done: isCompleted,
                    ),
                  ),
                if (requiresAdUnlock)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
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

class _PixelDialogButton extends StatelessWidget {
  const _PixelDialogButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: filled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF0C2),
                      Color(0xFFFFD56A),
                      Color(0xFFE0A93A),
                    ],
                  )
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: filled
                  ? const Color(0xFFFFE7A0)
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: filled
                    ? const Color(0xFF2A2410)
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
