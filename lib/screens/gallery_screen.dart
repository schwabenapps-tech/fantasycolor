import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../data/event_tags.dart';
import '../models/coloring_page.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/favorites_store.dart';
import '../services/audio_service.dart';
import '../utils/app_layout.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/event_badges.dart';
import '../widgets/progress_badge.dart';
import '../widgets/silver_back_button.dart';
import 'coloring_preview_screen.dart';
import 'favorites_screen.dart';

/// Galerie für klassisches Ausmalen.
///
/// Pixel Art ist vorerst ausgeblendet — Motive dort waren zu detailreich;
/// später eigene minimalistische Sets.
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
  Future<List<ColoringPage>>? _pagesFuture;
  Future<EventTags>? _tagsFuture;

  @override
  void initState() {
    super.initState();
    _ensureFutures();
    // Galerie = normale Fantasy-Musik (Halloween nur im Motiv selbst).
    unawaited(AudioService.instance.startAmbient(halloween: false));
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
    _pagesFuture ??= loadColoringPages();
    _tagsFuture ??= EventTags.load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    _ensureFutures();
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final tileHeight = layout.galleryTileHeight;
    final favorites = context.watch<FavoritesStore>();
    final progress = context.watch<ColoringProgressStore>();

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
                      if (layout.isLandscape)
                        SizedBox(height: layout.galleryTopSpacer * 0.55),
                      Expanded(
                        child: FutureBuilder<List<Object>>(
                          future: Future.wait([
                            _pagesFuture!,
                            _tagsFuture!,
                          ]),
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

                            final data = snapshot.data;
                            final pages = data == null
                                ? const <ColoringPage>[]
                                : data[0] as List<ColoringPage>;
                            final tags = data == null
                                ? null
                                : data[1] as EventTags;
                            if (pages.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Keine Ausmalbilder gefunden',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }

                            if (layout.isPortrait) {
                              return GridView.builder(
                                padding: layout.galleryGridPadding(size).copyWith(
                                  top: 56,
                                ),
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
                                  final halloween = tags
                                          ?.isHalloweenColoring(page.id) ??
                                      false;
                                  final isNew = !halloween &&
                                      (tags?.isFeaturedColoring(page.id) ??
                                          false);
                                  return _ColoringPageTile(
                                    page: page,
                                    isFavorite:
                                        favorites.isFavorite(page.id),
                                    hasProgress:
                                        progress.hasProgress(page.id),
                                    isHalloween: halloween,
                                    isNew: isNew,
                                    compact: true,
                                    onTap: () => _openSimplePage(page),
                                    onToggleFavorite: () =>
                                        favorites.toggle(page.id),
                                  );
                                },
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
                                    final halloween =
                                        tags?.isHalloweenColoring(page.id) ??
                                            false;
                                    final isNew = !halloween &&
                                        (tags?.isFeaturedColoring(page.id) ??
                                            false);
                                    return SizedBox(
                                      width: pageTileWidth,
                                      height: tileHeight,
                                      child: _ColoringPageTile(
                                        page: page,
                                        isFavorite:
                                            favorites.isFavorite(page.id),
                                        hasProgress:
                                            progress.hasProgress(page.id),
                                        isHalloween: halloween,
                                        isNew: isNew,
                                        onTap: () => _openSimplePage(page),
                                        onToggleFavorite: () =>
                                            favorites.toggle(page.id),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (layout.isLandscape)
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

class _ColoringPageTile extends StatelessWidget {
  const _ColoringPageTile({
    required this.page,
    required this.isFavorite,
    required this.hasProgress,
    required this.isHalloween,
    required this.isNew,
    required this.onTap,
    required this.onToggleFavorite,
    this.compact = false,
  });

  final ColoringPage page;
  final bool isFavorite;
  final bool hasProgress;
  final bool isHalloween;
  final bool isNew;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final framed = GalleryFrame(
      style: isHalloween
          ? GalleryFrameStyle.halloween
          : GalleryFrameStyle.fantasy,
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onTap,
            child: framed,
          ),
        ),
        if (isNew)
          Positioned(
            left: inset,
            top: inset,
            child: const NewBadge(),
          ),
        if (hasProgress)
          Positioned(
            left: inset,
            bottom: inset,
            child: const ProgressBadge(),
          ),
        Positioned(
          top: inset,
          right: inset,
          child: FavoriteStarButton(
            isFavorite: isFavorite,
            onPressed: onToggleFavorite,
            size: starSize,
          ),
        ),
      ],
    );
  }
}
