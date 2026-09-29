import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../data/puzzle_images_loader.dart';
import '../models/coloring_page.dart';
import '../models/pixel_puzzle.dart';
import '../providers/favorites_store.dart';
import '../providers/pixel_progress_store.dart';
import '../utils/app_layout.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/progress_badge.dart';
import '../widgets/silver_back_button.dart';
import 'coloring_preview_screen.dart';
import 'pixel_paint_screen.dart';
import '../utils/app_page_route.dart';

/// Rasteransicht: favorisierte Ausmalbilder + fertige Pixelbilder.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final Future<_FavoriteCatalog> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
  }

  Future<_FavoriteCatalog> _loadCatalog() async {
    final coloring = await loadColoringPages(shuffle: false);
    final pixels = await loadPuzzleImages(shuffle: false);
    return _FavoriteCatalog(coloring: coloring, pixels: pixels);
  }

  void _openColoringPage(ColoringPage page) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => ColoringPreviewScreen(page: page),
      ),
    );
  }

  Future<void> _openCompletedPixel(ColoringPage page) async {
    HapticFeedback.selectionClick();
    final store = context.read<PixelProgressStore>();
    final existing = await store.loadSnapshot(page.id);
    if (!mounted) return;

    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PixelPaintScreen(
              page: page,
              difficulty: PixelDifficulty.standard,
              resumeSnapshot: existing,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final favorites = context.watch<FavoritesStore>();
    final pixelProgress = context.watch<PixelProgressStore>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            FavoritesScreen.backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
                  child: Row(
                    children: [
                      SilverBackButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFD56A),
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Favoriten',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          shadows: const [
                            Shadow(
                              color: Color(0xAA000000),
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<_FavoriteCatalog>(
                    future: _catalogFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xFFFFD56A),
                            ),
                          ),
                        );
                      }

                      final catalog = snapshot.data ??
                          const _FavoriteCatalog(
                            coloring: [],
                            pixels: [],
                          );
                      final entries = <_FavoriteEntry>[
                        for (final page in catalog.coloring)
                          if (favorites.isFavorite(page.id))
                            _FavoriteEntry.coloring(page),
                        for (final page in catalog.pixels)
                          if (pixelProgress.isCompleted(page.id))
                            _FavoriteEntry.pixel(
                              page,
                              previewFile:
                                  pixelProgress.previewFileFor(page.id),
                              progressVersion:
                                  pixelProgress.versionOf(page.id),
                            ),
                      ];

                      if (entries.isEmpty) {
                        return Center(
                          child: Text(
                            'Noch keine Favoriten gespeichert',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 16,
                              shadows: const [
                                Shadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          size.width * 0.05,
                          8,
                          size.width * 0.05,
                          20,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: AppLayout.of(context)
                              .favoritesCrossAxisCount(landscape: true),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          if (entry.isPixel) {
                            return _FavoritePixelTile(
                              page: entry.page,
                              previewFile: entry.previewFile,
                              progressVersion: entry.progressVersion,
                              onOpen: () => unawaited(
                                _openCompletedPixel(entry.page),
                              ),
                            );
                          }
                          return _FavoriteGridTile(
                            page: entry.page,
                            isFavorite: favorites.isFavorite(entry.page.id),
                            onOpen: () => _openColoringPage(entry.page),
                            onToggleFavorite: () =>
                                favorites.toggle(entry.page.id),
                          );
                        },
                      );
                    },
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

class _FavoriteCatalog {
  const _FavoriteCatalog({
    required this.coloring,
    required this.pixels,
  });

  final List<ColoringPage> coloring;
  final List<ColoringPage> pixels;
}

class _FavoriteEntry {
  const _FavoriteEntry._({
    required this.page,
    required this.isPixel,
    this.previewFile,
    this.progressVersion = 0,
  });

  factory _FavoriteEntry.coloring(ColoringPage page) =>
      _FavoriteEntry._(page: page, isPixel: false);

  factory _FavoriteEntry.pixel(
    ColoringPage page, {
    File? previewFile,
    int progressVersion = 0,
  }) =>
      _FavoriteEntry._(
        page: page,
        isPixel: true,
        previewFile: previewFile,
        progressVersion: progressVersion,
      );

  final ColoringPage page;
  final bool isPixel;
  final File? previewFile;
  final int progressVersion;
}

class _FavoritePixelTile extends StatelessWidget {
  const _FavoritePixelTile({
    required this.page,
    required this.previewFile,
    required this.progressVersion,
    required this.onOpen,
  });

  final ColoringPage page;
  final File? previewFile;
  final int progressVersion;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
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
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: ColoredBox(
                    color: Colors.white,
                    child: previewFile != null
                        ? Image.file(
                            previewFile!,
                            key: ValueKey(
                              'fav_pixel_${page.id}_$progressVersion',
                            ),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => ColoringPageImage(
                              page: page,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(11),
                              placeholderSize: 22,
                            ),
                          )
                        : ColoringPageImage(
                            page: page,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(11),
                            placeholderSize: 22,
                          ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 8,
            bottom: 8,
            child: ProgressBadge(label: 'Fertig', done: true),
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
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }
}

class _FavoriteGridTile extends StatelessWidget {
  const _FavoriteGridTile({
    required this.page,
    required this.isFavorite,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final ColoringPage page;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
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
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ColoringPageImage(
                  page: page,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(11),
                  placeholderSize: 22,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: FavoriteStarButton(
              isFavorite: isFavorite,
              onPressed: onToggleFavorite,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stern zum Merken von Favoriten auf den Bildkarten.
class FavoriteStarButton extends StatelessWidget {
  const FavoriteStarButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.size = 42,
  });

  final bool isFavorite;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.35),
            border: Border.all(
              color: isFavorite
                  ? const Color(0xFFFFE29A)
                  : Colors.white.withValues(alpha: 0.55),
              width: 1.2,
            ),
            // Feste Glow-Fläche — kein Layout-Sprung beim Togglen.
            boxShadow: [
              BoxShadow(
                color: isFavorite
                    ? const Color(0xFFFFD56A).withValues(alpha: 0.45)
                    : Colors.transparent,
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: isFavorite
                ? const Color(0xFFFFD56A)
                : Colors.white.withValues(alpha: 0.9),
            size: size * 0.62,
          ),
        ),
      ),
    );
  }
}

/// Goldener Favoriten-Stern für die Galerie-Hauptseite (ohne Kreis).
class GoldenFavoritesButton extends StatelessWidget {
  const GoldenFavoritesButton({
    super.key,
    required this.onPressed,
    this.size = 36,
  });

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size + 12, height: size + 12),
      splashRadius: size * 0.75,
      icon: Icon(
        Icons.star_rounded,
        size: size,
        color: const Color(0xFFFFD56A),
        shadows: [
          Shadow(
            color: const Color(0xFFFFD56A).withValues(alpha: 0.55),
            blurRadius: 12,
          ),
          const Shadow(
            color: Color(0xAA000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
