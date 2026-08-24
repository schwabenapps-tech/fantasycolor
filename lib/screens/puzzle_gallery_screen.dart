import 'package:flutter/material.dart';

import '../data/puzzle_images_loader.dart';
import '../models/coloring_page.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/silver_back_button.dart';
import 'puzzle_screen.dart';

/// Galerie zur Auswahl der Puzzle-Bilder.
class PuzzleGalleryScreen extends StatefulWidget {
  const PuzzleGalleryScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

  @override
  State<PuzzleGalleryScreen> createState() => _PuzzleGalleryScreenState();
}

class _PuzzleGalleryScreenState extends State<PuzzleGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Future<List<ColoringPage>> _puzzlesFuture;

  @override
  void initState() {
    super.initState();
    _puzzlesFuture = loadPuzzleImages();
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

  void _openPuzzle(ColoringPage puzzle) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: PuzzleScreen(puzzle: puzzle),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tileHeight = size.height * 0.58;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            PuzzleGalleryScreen.backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Stack(
                children: [
                  FutureBuilder<List<ColoringPage>>(
                    future: _puzzlesFuture,
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

                      final puzzles = snapshot.data ?? const <ColoringPage>[];
                      if (puzzles.isEmpty) {
                        return const Center(
                          child: Text(
                            'Keine Puzzle-Bilder gefunden',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          SizedBox(height: size.height * 0.12),
                          Expanded(
                            child: Align(
                              alignment: const Alignment(0, 0.4),
                              child: SizedBox(
                                height: tileHeight,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: size.width * 0.055,
                                  ),
                                  itemCount: puzzles.length,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(width: size.width * 0.03),
                                  itemBuilder: (context, index) {
                                    final puzzle = puzzles[index];
                                    final ratio = puzzle.aspectRatio <= 0
                                        ? 0.72
                                        : puzzle.aspectRatio;
                                    final tileWidth = tileHeight * ratio;
                                    return _PuzzleTile(
                                      puzzle: puzzle,
                                      width: tileWidth.clamp(
                                        tileHeight * 0.55,
                                        tileHeight * 1.15,
                                      ),
                                      height: tileHeight,
                                      onTap: () => _openPuzzle(puzzle),
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

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({
    required this.puzzle,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final ColoringPage puzzle;
  final double width;
  final double height;
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
                Color(0xFFF4F7FC),
                Color(0xFFB8C0D0),
                Color(0xFF8E97A8),
                Color(0xFFE6EAF2),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC9A6FF).withValues(alpha: 0.32),
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
              page: puzzle,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
