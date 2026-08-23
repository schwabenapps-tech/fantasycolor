import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/coloring_pages_loader.dart';
import '../models/coloring_page.dart';
import '../providers/favorites_store.dart';
import '../widgets/coloring_page_image.dart';
import 'coloring_preview_screen.dart';
import 'favorites_screen.dart';
import 'print_templates_screen.dart';
import 'puzzle_gallery_screen.dart';

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

  void _openPuzzles() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const PuzzleGalleryScreen(),
          );
        },
      ),
    );
  }

  void _openPrintTemplates() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const PrintTemplatesScreen(),
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
                    left: 12,
                    child: _SilverBackButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 14,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FantasyPuzzleEntryButton(onPressed: _openPuzzles),
                        const SizedBox(width: 8),
                        FantasyPrintEntryButton(
                          onPressed: _openPrintTemplates,
                        ),
                        const SizedBox(width: 8),
                        GoldenFavoritesButton(onPressed: _openFavorites),
                      ],
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

/// Sanfter Puzzle-Einstieg für die Ausmal-Galerie.
class FantasyPuzzleEntryButton extends StatefulWidget {
  const FantasyPuzzleEntryButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  State<FantasyPuzzleEntryButton> createState() =>
      _FantasyPuzzleEntryButtonState();
}

class _FantasyPuzzleEntryButtonState extends State<FantasyPuzzleEntryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return _GalleryChipButton(
      label: 'Puzzle',
      icon: Icons.extension_rounded,
      pressed: _pressed,
      onPressedChanged: (value) => setState(() => _pressed = value),
      onPressed: widget.onPressed,
      colors: const [
        Color(0xFFFFF7FB),
        Color(0xFFE9D7FF),
        Color(0xFFD4B8F5),
        Color(0xFFF3E8FF),
      ],
      iconColor: const Color(0xFF6B4FA0),
      textColor: const Color(0xFF4A356E),
      glowColor: const Color(0xFFC9A6FF),
    );
  }
}

/// Einstieg zu ausdruckbaren Ausmalvorlagen.
class FantasyPrintEntryButton extends StatefulWidget {
  const FantasyPrintEntryButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  State<FantasyPrintEntryButton> createState() =>
      _FantasyPrintEntryButtonState();
}

class _FantasyPrintEntryButtonState extends State<FantasyPrintEntryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return _GalleryChipButton(
      label: 'Drucken',
      icon: Icons.print_rounded,
      pressed: _pressed,
      onPressedChanged: (value) => setState(() => _pressed = value),
      onPressed: widget.onPressed,
      colors: const [
        Color(0xFFF7FBFF),
        Color(0xFFD7ECFF),
        Color(0xFFB8DAF5),
        Color(0xFFE8F4FF),
      ],
      iconColor: const Color(0xFF3F6FA0),
      textColor: const Color(0xFF2F5478),
      glowColor: const Color(0xFF9EC8FF),
    );
  }
}

class _GalleryChipButton extends StatelessWidget {
  const _GalleryChipButton({
    required this.label,
    required this.icon,
    required this.pressed,
    required this.onPressedChanged,
    required this.onPressed,
    required this.colors,
    required this.iconColor,
    required this.textColor,
    required this.glowColor,
  });

  final String label;
  final IconData icon;
  final bool pressed;
  final ValueChanged<bool> onPressedChanged;
  final VoidCallback onPressed;
  final List<Color> colors;
  final Color iconColor;
  final Color textColor;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTapDown: (_) => onPressedChanged(true),
        onTapUp: (_) {
          onPressedChanged(false);
          onPressed();
        },
        onTapCancel: () => onPressedChanged(false),
        child: AnimatedScale(
          scale: pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: iconColor,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFFFD56A).withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.95),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.7),
                        blurRadius: 4,
                      ),
                    ],
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
