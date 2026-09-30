import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/event_catalog.dart';
import '../models/coloring_page.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/favorites_store.dart';
import '../screens/favorites_screen.dart';
import '../services/analytics_service.dart';
import '../services/gallery_export.dart';
import '../utils/app_layout.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/event_badges.dart';
import '../widgets/progress_badge.dart';
import '../widgets/silver_back_button.dart';
import 'coloring_preview_screen.dart';
import 'puzzle_screen.dart';
import '../utils/app_page_route.dart';

/// Galerie nur für ein Event-Pack (nach Tippen auf den Event-Hub).
class EventPackGalleryScreen extends StatelessWidget {
  const EventPackGalleryScreen({
    super.key,
    required this.section,
    required this.coloring,
    this.halloweenIds = const {},
  });

  final GallerySection section;
  final bool coloring;
  final Set<String> halloweenIds;

  static const backgroundAsset = 'assets/images/in_app_background.png';

  void _open(BuildContext context, ColoringPage page) {
    if (coloring) {
      AnalyticsService.instance.logStartColoring(page.id);
      Navigator.of(context).push(
        AppPageRoute<void>(
        builder: (_) => ColoringPreviewScreen(page: page),
      ),
      );
    } else {
      AnalyticsService.instance.logStartPuzzle(page.id);
      Navigator.of(context).push(
        AppPageRoute<void>(
        builder: (_) => PuzzleScreen(puzzle: page),
      ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final pages = section.pages;
    final tileHeight = layout.galleryTileHeight;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(56, 14, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          section.title,
                          style: TextStyle(
                            color: section.isPastEvent
                                ? const Color(0xFFB8C0D4)
                                : const Color(0xFFFFB86B),
                            fontSize: layout.isTablet ? 28 : 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: pages.isEmpty
                          ? const Center(
                              child: Text(
                                'No images in this event',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : layout.isPortrait
                              ? GridView.builder(
                                  padding: layout
                                      .galleryGridPadding(size)
                                      .copyWith(top: 8),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        layout.galleryGridCrossAxisCount,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio:
                                        layout.galleryGridChildAspectRatio,
                                  ),
                                  itemCount: pages.length,
                                  itemBuilder: (context, index) {
                                    final page = pages[index];
                                    return GalleryPageTile(
                                      page: page,
                                      isHalloween:
                                          halloweenIds.contains(page.id),
                                      isNew: false,
                                      compact: true,
                                      showDownloadButton: !coloring,
                                      favoriteKind: coloring
                                          ? FavoriteKind.coloring
                                          : FavoriteKind.puzzle,
                                      onTap: () => _open(context, page),
                                    );
                                  },
                                )
                              : Align(
                                  alignment: const Alignment(0, 0.2),
                                  child: SizedBox(
                                    height: tileHeight,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: size.width * 0.05,
                                      ),
                                      itemCount: pages.length,
                                      separatorBuilder: (_, _) =>
                                          SizedBox(width: size.width * 0.03),
                                      itemBuilder: (context, index) {
                                        final page = pages[index];
                                        final ratio = page.aspectRatio <= 0
                                            ? 0.78
                                            : page.aspectRatio;
                                        final w = (tileHeight * ratio).clamp(
                                          tileHeight * 0.55,
                                          tileHeight * 1.75,
                                        );
                                        return SizedBox(
                                          width: w,
                                          height: tileHeight,
                                          child: GalleryPageTile(
                                            page: page,
                                            isHalloween: halloweenIds
                                                .contains(page.id),
                                            isNew: false,
                                            showDownloadButton: !coloring,
                                            favoriteKind: coloring
                                                ? FavoriteKind.coloring
                                                : FavoriteKind.puzzle,
                                            onTap: () =>
                                                _open(context, page),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                    ),
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
        ],
      ),
    );
  }
}

/// Gemeinsame Vorschaukachel (Ausmalen / Puzzle / Event-Pack).
class GalleryPageTile extends StatelessWidget {
  const GalleryPageTile({
    super.key,
    required this.page,
    required this.isHalloween,
    required this.isNew,
    required this.onTap,
    this.compact = false,
    this.showDownloadButton = false,
    this.favoriteKind = FavoriteKind.coloring,
    this.showFavoriteButton = true,
  });

  final ColoringPage page;
  final bool isHalloween;
  final bool isNew;
  final bool compact;
  final bool showDownloadButton;
  final FavoriteKind favoriteKind;
  final bool showFavoriteButton;
  final VoidCallback onTap;

  Future<void> _saveToPhotos(BuildContext context) async {
    try {
      await GalleryExport.saveAsset(
        page.assetPath,
        name: 'fantasy_puzzle_${page.id}',
      );
      if (!context.mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Photos!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final framed = GalleryFrame(
      style: isHalloween
          ? GalleryFrameStyle.halloween
          : GalleryFrameStyle.fantasy,
      showHalloweenBadge: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: compact
            ? SizedBox.expand(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.95),
                  child: ColoringPageImage(
                    page: page,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            : ColoredBox(
                color: Colors.white.withValues(alpha: 0.95),
                child: ColoringPageImage(
                  page: page,
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
      ),
    );

    final starSize = compact ? 34.0 : 42.0;
    final inset = compact ? 8.0 : 12.0;
    final downloadSize = compact ? 34.0 : 40.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(onTap: onTap, child: framed),
        ),
        if (isNew)
          Positioned(
            left: inset,
            top: inset,
            child: const NewBadge(),
          ),
        if (!showDownloadButton)
          Selector<ColoringProgressStore, bool>(
            selector: (_, store) => store.hasProgress(page.id),
            builder: (context, hasProgress, _) {
              if (!hasProgress) return const SizedBox.shrink();
              return Positioned(
                left: inset,
                bottom: inset,
                child: const ProgressBadge(label: 'Continue'),
              );
            },
          ),
        if (showFavoriteButton)
          Positioned(
            top: inset,
            right: inset,
            child: Selector<FavoritesStore, bool>(
              selector: (_, store) =>
                  store.isFavorite(page.id, kind: favoriteKind),
              builder: (context, isFavorite, _) {
                return FavoriteStarButton(
                  isFavorite: isFavorite,
                  onPressed: () => context.read<FavoritesStore>().toggle(
                        page.id,
                        kind: favoriteKind,
                      ),
                  size: starSize,
                );
              },
            ),
          ),
        if (showDownloadButton)
          Positioned(
            right: inset,
            bottom: inset,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => unawaited(_saveToPhotos(context)),
                customBorder: const CircleBorder(),
                child: Ink(
                  width: downloadSize,
                  height: downloadSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.65),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: downloadSize * 0.55,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
