import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../models/coloring_page.dart';
import '../providers/favorites_store.dart';
import '../widgets/coloring_page_image.dart';
import 'coloring_preview_screen.dart';

/// Rasteransicht aller favorisierten Ausmalbilder.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final Future<List<ColoringPage>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = loadColoringPages(shuffle: false);
  }

  void _openPage(ColoringPage page) {
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
                      _SilverBackButton(
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
                  child: FutureBuilder<List<ColoringPage>>(
                    future: _pagesFuture,
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

                      final allPages = snapshot.data ?? const <ColoringPage>[];
                      final pages = allPages
                          .where((page) => favorites.isFavorite(page.id))
                          .toList(growable: false);

                      if (pages.isEmpty) {
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
                          crossAxisCount: size.width > 900 ? 4 : 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          final page = pages[index];
                          return _FavoriteGridTile(
                            page: page,
                            isFavorite: favorites.isFavorite(page.id),
                            onOpen: () => _openPage(page),
                            onToggleFavorite: () => favorites.toggle(page.id),
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
      child: Column(
        children: [
          Expanded(
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
          ),
          const SizedBox(height: 8),
          Text(
            page.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(
                  color: Color(0xAA000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SilverBackButton extends StatelessWidget {
  const _SilverBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF7F9FC),
                Color(0xFFC5CCD8),
                Color(0xFF9AA3B5),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF243044),
            size: 22,
          ),
        ),
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
            boxShadow: [
              if (isFavorite)
                BoxShadow(
                  color: const Color(0xFFFFD56A).withValues(alpha: 0.45),
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
