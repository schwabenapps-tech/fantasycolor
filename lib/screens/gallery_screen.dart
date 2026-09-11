import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../data/paint_catalog.dart';
import '../data/puzzle_images_loader.dart';
import '../models/coloring_page.dart';
import '../models/pixel_puzzle.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/favorites_store.dart';
import '../providers/pixel_mode_unlock_store.dart';
import '../providers/pixel_progress_store.dart';
import '../utils/app_layout.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/progress_badge.dart';
import '../widgets/silver_back_button.dart';
import 'coloring_preview_screen.dart';
import 'favorites_screen.dart';
import 'pixel_gallery_screen.dart';
import 'pixel_paint_screen.dart';

/// Bildergalerie mit Filter: Einfach (Ausmalen) / Fortgeschritten (Pixel).
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  Future<List<ColoringPage>>? _simpleFuture;
  Future<List<ColoringPage>>? _advancedFuture;
  MalenFilter _filter = MalenFilter.einfach;

  @override
  void initState() {
    super.initState();
    _ensureFutures();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  /// Hot-Reload-sicher: Futures ggf. nachträglich anlegen.
  void _ensureFutures() {
    _simpleFuture ??= loadColoringPages();
    _advancedFuture ??= loadPuzzleImages();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _selectFilter(MalenFilter filter) async {
    HapticFeedback.selectionClick();
    if (filter == MalenFilter.fortgeschritten) {
      final unlock = context.read<PixelModeUnlockStore>();
      if (!unlock.isUnlocked) {
        final wants = await showPixelUnlockDialog(context);
        if (wants != true || !mounted) return;
        await openPixelModeUnlockOnly(context);
        if (!mounted) return;
        if (!context.read<PixelModeUnlockStore>().isUnlocked) return;
      }
    }
    if (!mounted) return;
    setState(() => _filter = filter);
  }

  void _openSimplePage(ColoringPage page) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: ColoringPreviewScreen(page: page),
          );
        },
      ),
    );
  }

  Future<void> _openPixelPage(ColoringPage page) async {
    HapticFeedback.selectionClick();
    final store = context.read<PixelProgressStore>();
    final existing = await store.loadSnapshot(page.id);

    if (!mounted) return;

    if (existing != null && !existing.completed && existing.filledCount > 0) {
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: PixelPaintScreen(
                page: page,
                difficulty: PixelDifficulty.standard,
                resumeSnapshot: existing,
              ),
            );
          },
        ),
      );
      return;
    }

    // Neustart: alten Stand verwerfen.
    if (existing != null) {
      await store.clearProgress(page.id);
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: PixelPaintScreen(
              page: page,
              difficulty: PixelDifficulty.standard,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureFutures();
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final tileHeight = layout.galleryTileHeight;
    final favorites = context.watch<FavoritesStore>();
    final progress = context.watch<ColoringProgressStore>();
    final pixelProgress = context.watch<PixelProgressStore>();
    final pixelUnlocked = context.watch<PixelModeUnlockStore>().isUnlocked;
    final isAdvanced = _filter == MalenFilter.fortgeschritten;
    final pagesFuture =
        isAdvanced ? _advancedFuture! : _simpleFuture!;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            GalleryScreen.backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      SizedBox(height: layout.galleryTopSpacer * 0.45),
                      _MalenFilterBar(
                        filter: _filter,
                        advancedUnlocked: pixelUnlocked,
                        onSelect: _selectFilter,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _filter.hint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: FutureBuilder<List<ColoringPage>>(
                          future: pagesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
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

                            final pages =
                                snapshot.data ?? const <ColoringPage>[];
                            if (pages.isEmpty) {
                              return Center(
                                child: Text(
                                  isAdvanced
                                      ? 'Keine Pixel-Bilder gefunden'
                                      : 'Keine Ausmalbilder gefunden',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }

                            return Align(
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
                                    // Kachelbreite am echten Bildformat — sonst
                                    // werden Querformat-Motive mit cover abgeschnitten.
                                    final ratio = page.aspectRatio <= 0
                                        ? 0.78
                                        : page.aspectRatio;
                                    final pageTileWidth = (tileHeight * ratio)
                                        .clamp(
                                          tileHeight * 0.55,
                                          tileHeight * 1.75,
                                        );
                                    if (isAdvanced) {
                                      return _PixelPageTile(
                                        page: page,
                                        width: pageTileWidth,
                                        height: tileHeight,
                                        hasProgress:
                                            pixelProgress.hasProgress(page.id),
                                        isCompleted: pixelProgress
                                            .isCompleted(page.id),
                                        progressVersion:
                                            pixelProgress.versionOf(page.id),
                                        previewFile: pixelProgress
                                            .previewFileFor(page.id),
                                        onTap: () => _openPixelPage(page),
                                      );
                                    }
                                    return _ColoringPageTile(
                                      page: page,
                                      width: pageTileWidth,
                                      height: tileHeight,
                                      isFavorite:
                                          favorites.isFavorite(page.id),
                                      hasProgress:
                                          progress.hasProgress(page.id),
                                      onTap: () => _openSimplePage(page),
                                      onToggleFavorite: () =>
                                          favorites.toggle(page.id),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: size.height * 0.03),
                    ],
                  ),
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
          ),
        ],
      ),
    );
  }
}

class _MalenFilterBar extends StatelessWidget {
  const _MalenFilterBar({
    required this.filter,
    required this.advancedUnlocked,
    required this.onSelect,
  });

  final MalenFilter filter;
  final bool advancedUnlocked;
  final ValueChanged<MalenFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.black.withValues(alpha: 0.32),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (final f in MalenFilter.values) ...[
                Expanded(
                  child: _FilterChip(
                    filter: f,
                    selected: filter == f,
                    locked: f == MalenFilter.fortgeschritten &&
                        !advancedUnlocked,
                    onTap: () => onSelect(f),
                  ),
                ),
                if (f != MalenFilter.values.last) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final MalenFilter filter;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: filter == MalenFilter.fortgeschritten
                        ? const [
                            Color(0xFFFFF0C2),
                            Color(0xFFFFD56A),
                            Color(0xFFE0A93A),
                          ]
                        : const [
                            Color(0xFFE9D7FF),
                            Color(0xFFD4B8F5),
                            Color(0xFFB89AE0),
                          ],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.06),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                locked ? Icons.lock_rounded : filter.icon,
                size: 16,
                color: selected
                    ? const Color(0xFF2A2410)
                    : Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  filter.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF2A2410)
                        : Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class _PixelPageTile extends StatelessWidget {
  const _PixelPageTile({
    required this.page,
    required this.width,
    required this.height,
    required this.hasProgress,
    required this.isCompleted,
    required this.progressVersion,
    required this.previewFile,
    required this.onTap,
  });

  final ColoringPage page;
  final double width;
  final double height;
  final bool hasProgress;
  final bool isCompleted;
  final int progressVersion;
  final File? previewFile;
  final VoidCallback onTap;

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
                      child: previewFile != null
                          ? Image.file(
                              previewFile!,
                              key: ValueKey(
                                'pixel_preview_${page.id}_$progressVersion',
                              ),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) => ColoringPageImage(
                                page: page,
                                fit: BoxFit.cover,
                              ),
                            )
                          : ColoringPageImage(
                              page: page,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
                if (hasProgress)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: ProgressBadge(
                      label: isCompleted ? 'Fertig' : 'Weiter',
                      done: isCompleted,
                    ),
                  ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_on_rounded,
                            size: 14,
                            color: Color(0xFFFFE7A0),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Nach Zahlen',
                            style: TextStyle(
                              color: Color(0xFFFFE7A0),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

class _ColoringPageTile extends StatelessWidget {
  const _ColoringPageTile({
    required this.page,
    required this.width,
    required this.height,
    required this.isFavorite,
    required this.hasProgress,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final ColoringPage page;
  final double width;
  final double height;
  final bool isFavorite;
  final bool hasProgress;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF4F7FC),
                      Color(0xFFB8C0D0),
                      Color(0xFF8E97A8),
                      Color(0xFFE6EAF2),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9EC8FF).withValues(alpha: 0.28),
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
                  child: ColoringPageImage(
                    page: page,
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          if (hasProgress)
            const Positioned(
              left: 12,
              bottom: 12,
              child: ProgressBadge(),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: FavoriteStarButton(
              isFavorite: isFavorite,
              onPressed: onToggleFavorite,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }
}
