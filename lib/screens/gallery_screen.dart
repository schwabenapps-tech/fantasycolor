import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../models/coloring_page.dart';
import '../providers/favorites_store.dart';
import '../widgets/coloring_page_image.dart';
import 'coloring_preview_screen.dart';
import 'favorites_screen.dart';

/// Bildergalerie / Auswahl der Ausmalbilder.
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
  late final Future<List<ColoringPage>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = loadColoringPages();
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

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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

  void _openFavorites() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const FavoritesScreen(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tileHeight = size.height * 0.56;
    final tileWidth = tileHeight * 0.78;
    final favorites = context.watch<FavoritesStore>();

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
                  FutureBuilder<List<ColoringPage>>(
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

                      final pages = snapshot.data ?? const <ColoringPage>[];
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

                      return Column(
                        children: [
                          SizedBox(height: size.height * 0.14),
                          Expanded(
                            child: Align(
                              alignment: const Alignment(0, 0.55),
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
                                    return _ColoringPageTile(
                                      page: page,
                                      width: tileWidth,
                                      height: tileHeight,
                                      isFavorite:
                                          favorites.isFavorite(page.id),
                                      onTap: () => _openPage(page),
                                      onToggleFavorite: () =>
                                          favorites.toggle(page.id),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.04),
                        ],
                      );
                    },
                  ),
                  Positioned(
                    top: 10,
                    right: 16,
                    child: GoldenFavoritesButton(onPressed: _openFavorites),
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
    required this.width,
    required this.height,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final ColoringPage page;
  final double width;
  final double height;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Expanded(
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
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
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
          ),
          const SizedBox(height: 10),
          Text(
            page.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
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
    );
  }
}
