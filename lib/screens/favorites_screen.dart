import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../data/puzzle_images_loader.dart';
import '../models/coloring_page.dart';
import '../providers/favorites_store.dart';
import '../utils/app_layout.dart';
import '../utils/app_page_route.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/silver_back_button.dart';
import 'coloring_preview_screen.dart';
import 'puzzle_screen.dart';

/// Favoriten-Liste: nur Color / Puzzle-Karten.
/// Gespeicherte Bilder öffnen auf einem eigenen Screen.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';
  static const coloringEmptyLogo = 'assets/images/malen_favorit.png';
  static const puzzleEmptyLogo = 'assets/images/puzzle_favorit.png';

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
    final puzzles = await loadPuzzleImages(shuffle: false);
    return _FavoriteCatalog(coloring: coloring, puzzles: puzzles);
  }

  void _openCategory({
    required String title,
    required FavoriteKind kind,
    required String emptyLabel,
    required String emptyLogoAsset,
    required IconData emptyIcon,
    required List<ColoringPage> catalog,
  }) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => FavoriteImagesScreen(
          title: title,
          kind: kind,
          emptyLabel: emptyLabel,
          emptyLogoAsset: emptyLogoAsset,
          emptyIcon: emptyIcon,
          catalog: catalog,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final favorites = context.watch<FavoritesStore>();

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
                        'Favorites',
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
                          const _FavoriteCatalog(coloring: [], puzzles: []);
                      final coloringCount = favorites.coloringIds().length;
                      final puzzleCount = favorites.puzzleIds().length;

                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          size.width * 0.05,
                          12,
                          size.width * 0.05,
                          28,
                        ),
                        children: [
                          _FavoriteCategoryCard(
                            title: 'Color',
                            subtitle: coloringCount == 0
                                ? 'No coloring favorites yet'
                                : '$coloringCount saved',
                            logoAsset: FavoritesScreen.coloringEmptyLogo,
                            icon: Icons.palette_rounded,
                            count: coloringCount,
                            onTap: () => _openCategory(
                              title: 'Color',
                              kind: FavoriteKind.coloring,
                              emptyLabel: 'No coloring favorites yet',
                              emptyLogoAsset:
                                  FavoritesScreen.coloringEmptyLogo,
                              emptyIcon: Icons.palette_rounded,
                              catalog: catalog.coloring,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FavoriteCategoryCard(
                            title: 'Puzzle',
                            subtitle: puzzleCount == 0
                                ? 'No puzzle favorites yet'
                                : '$puzzleCount saved',
                            logoAsset: FavoritesScreen.puzzleEmptyLogo,
                            icon: Icons.extension_rounded,
                            count: puzzleCount,
                            onTap: () => _openCategory(
                              title: 'Puzzle',
                              kind: FavoriteKind.puzzle,
                              emptyLabel: 'No puzzle favorites yet',
                              emptyLogoAsset:
                                  FavoritesScreen.puzzleEmptyLogo,
                              emptyIcon: Icons.extension_rounded,
                              catalog: catalog.puzzles,
                            ),
                          ),
                        ],
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
    required this.puzzles,
  });

  final List<ColoringPage> coloring;
  final List<ColoringPage> puzzles;
}

/// Listen-Karte für Color / Puzzle (ohne Bildergitter).
class _FavoriteCategoryCard extends StatelessWidget {
  const _FavoriteCategoryCard({
    required this.title,
    required this.subtitle,
    required this.logoAsset,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String logoAsset;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF8EC),
                Color(0xFFE8C9A0),
                Color(0xFFD4B896),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC9A06A).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    logoAsset,
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: const Color(0xFF3A2810), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF2A2410),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 10),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF3A2810)
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD56A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color:
                              const Color(0xFF2A2410).withValues(alpha: 0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFF3A2810).withValues(alpha: 0.55),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Extra-Screen nur für die gespeicherten Bilder einer Kategorie.
class FavoriteImagesScreen extends StatelessWidget {
  const FavoriteImagesScreen({
    super.key,
    required this.title,
    required this.kind,
    required this.emptyLabel,
    required this.emptyLogoAsset,
    required this.emptyIcon,
    required this.catalog,
  });

  final String title;
  final FavoriteKind kind;
  final String emptyLabel;
  final String emptyLogoAsset;
  final IconData emptyIcon;
  final List<ColoringPage> catalog;

  void _open(BuildContext context, ColoringPage page) {
    if (kind == FavoriteKind.coloring) {
      Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (_) => ColoringPreviewScreen(page: page),
        ),
      );
    } else {
      HapticFeedback.selectionClick();
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
    final favorites = context.watch<FavoritesStore>();
    final ids = kind == FavoriteKind.coloring
        ? favorites.coloringIds()
        : favorites.puzzleIds();
    final byId = {for (final p in catalog) p.id: p};
    final pages = [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];

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
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
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
                  child: pages.isEmpty
                      ? Padding(
                          padding: EdgeInsets.fromLTRB(
                            size.width * 0.05,
                            20,
                            size.width * 0.05,
                            24,
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _EmptyFavoriteCard(
                              label: emptyLabel,
                              icon: emptyIcon,
                              logoAsset: emptyLogoAsset,
                            ),
                          ),
                        )
                      : layout.isLandscape
                          ? _FavoriteLandscapeRow(
                              pages: pages,
                              kind: kind,
                              favorites: favorites,
                              onOpen: (page) => _open(context, page),
                            )
                          : GridView.builder(
                              padding: EdgeInsets.fromLTRB(
                                size.width * 0.045,
                                10,
                                size.width * 0.045,
                                24,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: layout.favoritesCrossAxisCount(
                                  landscape: false,
                                ),
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.78,
                              ),
                              itemCount: pages.length,
                              itemBuilder: (context, index) {
                                final page = pages[index];
                                return _FavoriteGridTile(
                                  page: page,
                                  isFavorite: favorites.isFavorite(
                                    page.id,
                                    kind: kind,
                                  ),
                                  onOpen: () => _open(context, page),
                                  onToggleFavorite: () => favorites.toggle(
                                    page.id,
                                    kind: kind,
                                  ),
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

class _FavoriteLandscapeRow extends StatelessWidget {
  const _FavoriteLandscapeRow({
    required this.pages,
    required this.kind,
    required this.favorites,
    required this.onOpen,
  });

  final List<ColoringPage> pages;
  final FavoriteKind kind;
  final FavoritesStore favorites;
  final ValueChanged<ColoringPage> onOpen;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final tileHeight = layout.galleryTileHeight;

    return Align(
      alignment: const Alignment(0, 0.15),
      child: SizedBox(
        height: tileHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
          itemCount: pages.length,
          separatorBuilder: (_, _) => SizedBox(width: size.width * 0.03),
          itemBuilder: (context, index) {
            final page = pages[index];
            final ratio = page.aspectRatio <= 0 ? 0.78 : page.aspectRatio;
            final tileWidth = (tileHeight * ratio).clamp(
              tileHeight * 0.55,
              tileHeight * 1.75,
            );
            return SizedBox(
              width: tileWidth,
              height: tileHeight,
              child: _FavoriteGridTile(
                page: page,
                isFavorite: favorites.isFavorite(page.id, kind: kind),
                onOpen: () => onOpen(page),
                onToggleFavorite: () => favorites.toggle(page.id, kind: kind),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyFavoriteCard extends StatelessWidget {
  const _EmptyFavoriteCard({
    required this.label,
    required this.icon,
    required this.logoAsset,
  });

  final String label;
  final IconData icon;
  final String logoAsset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8EC),
            Color(0xFFE8C9A0),
            Color(0xFFD4B896),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC9A06A).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                logoAsset,
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: const Color(0xFF3A2810), size: 22),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: const Color(0xFF2A2410).withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        fit: StackFit.expand,
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
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: ColoringPageImage(
                  page: page,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(10),
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
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}

/// Star button used on gallery cards and favorites.
class FavoriteStarButton extends StatelessWidget {
  const FavoriteStarButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.size = 40,
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
            color: isFavorite
                ? const Color(0xFF3A2810).withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.35),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isFavorite
                    ? const Color(0xFFFFD56A).withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: isFavorite
                ? const Color(0xFFFFD56A)
                : Colors.white.withValues(alpha: 0.92),
            size: size * 0.58,
          ),
        ),
      ),
    );
  }
}
