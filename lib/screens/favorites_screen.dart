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

/// Favorites split into Color and Puzzle, newest first.
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

  void _openColoring(ColoringPage page) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => ColoringPreviewScreen(page: page),
      ),
    );
  }

  void _openPuzzle(ColoringPage page) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PuzzleScreen(puzzle: page),
      ),
    );
  }

  List<ColoringPage> _orderedPages(
    List<String> orderedIds,
    List<ColoringPage> catalog,
  ) {
    final byId = {for (final p in catalog) p.id: p};
    return [
      for (final id in orderedIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final favorites = context.watch<FavoritesStore>();
    final isPortrait = layout.isPortrait;

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
                      final coloringPages = _orderedPages(
                        favorites.coloringIds(),
                        catalog.coloring,
                      );
                      final puzzlePages = _orderedPages(
                        favorites.puzzleIds(),
                        catalog.puzzles,
                      );

                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          size.width * 0.05,
                          8,
                          size.width * 0.05,
                          24,
                        ),
                        children: [
                          _FavoriteSection(
                            title: 'Color',
                            emptyLabel: 'No coloring favorites yet',
                            emptyIcon: Icons.palette_rounded,
                            emptyLogoAsset: FavoritesScreen.coloringEmptyLogo,
                            pages: coloringPages,
                            isPortrait: isPortrait,
                            crossAxisCount:
                                layout.favoritesCrossAxisCount(landscape: true),
                            itemBuilder: (page) => _FavoriteGridTile(
                              page: page,
                              isFavorite: favorites.isFavorite(
                                page.id,
                                kind: FavoriteKind.coloring,
                              ),
                              onOpen: () => _openColoring(page),
                              onToggleFavorite: () => favorites.toggle(
                                page.id,
                                kind: FavoriteKind.coloring,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _FavoriteSection(
                            title: 'Puzzle',
                            emptyLabel: 'No puzzle favorites yet',
                            emptyIcon: Icons.extension_rounded,
                            emptyLogoAsset: FavoritesScreen.puzzleEmptyLogo,
                            pages: puzzlePages,
                            isPortrait: isPortrait,
                            crossAxisCount:
                                layout.favoritesCrossAxisCount(landscape: true),
                            itemBuilder: (page) => _FavoriteGridTile(
                              page: page,
                              isFavorite: favorites.isFavorite(
                                page.id,
                                kind: FavoriteKind.puzzle,
                              ),
                              onOpen: () => _openPuzzle(page),
                              onToggleFavorite: () => favorites.toggle(
                                page.id,
                                kind: FavoriteKind.puzzle,
                              ),
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

class _FavoriteSection extends StatelessWidget {
  const _FavoriteSection({
    required this.title,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.emptyLogoAsset,
    required this.pages,
    required this.isPortrait,
    required this.crossAxisCount,
    required this.itemBuilder,
  });

  final String title;
  final String emptyLabel;
  final IconData emptyIcon;
  final String emptyLogoAsset;
  final List<ColoringPage> pages;
  final bool isPortrait;
  final int crossAxisCount;
  final Widget Function(ColoringPage page) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            shadows: const [
              Shadow(color: Color(0xAA000000), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (pages.isEmpty)
          _EmptyFavoriteCard(
            label: emptyLabel,
            icon: emptyIcon,
            logoAsset: emptyLogoAsset,
          )
        else if (isPortrait)
          // Portrait: show newest favorite first as a large lead tile.
          Column(
            children: [
              AspectRatio(
                aspectRatio: 0.85,
                child: itemBuilder(pages.first),
              ),
              if (pages.length > 1) ...[
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pages.length - 1,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount.clamp(2, 4),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) =>
                      itemBuilder(pages[index + 1]),
                ),
              ],
            ],
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pages.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) => itemBuilder(pages[index]),
          ),
      ],
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
