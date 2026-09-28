import 'dart:async';

import 'package:flutter/material.dart';

import '../data/event_tags.dart';
import '../data/puzzle_images_loader.dart';
import '../models/coloring_page.dart';
import '../services/audio_service.dart';
import '../utils/app_layout.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/event_badges.dart';
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
  late final Future<EventTags> _tagsFuture;

  @override
  void initState() {
    super.initState();
    _puzzlesFuture = loadPuzzleImages();
    _tagsFuture = EventTags.load();
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
    final layout = AppLayout.of(context);
    final tileHeight = layout.puzzleGalleryTileHeight;

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
                  FutureBuilder<List<Object>>(
                    future: Future.wait([_puzzlesFuture, _tagsFuture]),
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

                      final data = snapshot.data;
                      final puzzles = data == null
                          ? const <ColoringPage>[]
                          : data[0] as List<ColoringPage>;
                      final tags =
                          data == null ? null : data[1] as EventTags;
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

                      if (layout.isPortrait) {
                        return GridView.builder(
                          padding: layout.galleryGridPadding(size).copyWith(
                            top: 56,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: layout.galleryGridCrossAxisCount,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio:
                                layout.galleryGridChildAspectRatio,
                          ),
                          itemCount: puzzles.length,
                          itemBuilder: (context, index) {
                            final puzzle = puzzles[index];
                            final halloween =
                                tags?.isHalloweenPuzzle(puzzle.id) ?? false;
                            final isNew = !halloween &&
                                (tags?.isFeaturedPuzzle(puzzle.id) ?? false);
                            return _PuzzleTile(
                              puzzle: puzzle,
                              isHalloween: halloween,
                              isNew: isNew,
                              compact: true,
                              onTap: () => _openPuzzle(puzzle),
                            );
                          },
                        );
                      }

                      return Column(
                        children: [
                          SizedBox(height: layout.puzzleGalleryTopSpacer),
                          Expanded(
                            child: Align(
                              alignment: const Alignment(0, 0.25),
                              child: SizedBox(
                                height: tileHeight,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: size.width * 0.04,
                                  ),
                                  itemCount: puzzles.length,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(width: size.width * 0.025),
                                  itemBuilder: (context, index) {
                                    final puzzle = puzzles[index];
                                    final ratio = puzzle.aspectRatio <= 0
                                        ? 0.72
                                        : puzzle.aspectRatio;
                                    final tileWidth = tileHeight * ratio;
                                    final halloween =
                                        tags?.isHalloweenPuzzle(puzzle.id) ??
                                            false;
                                    final isNew = !halloween &&
                                        (tags?.isFeaturedPuzzle(puzzle.id) ??
                                            false);
                                    return SizedBox(
                                      width: tileWidth.clamp(
                                        tileHeight * 0.6,
                                        tileHeight * 1.55,
                                      ),
                                      height: tileHeight,
                                      child: _PuzzleTile(
                                        puzzle: puzzle,
                                        isHalloween: halloween,
                                        isNew: isNew,
                                        onTap: () => _openPuzzle(puzzle),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.03),
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
    required this.isHalloween,
    required this.isNew,
    required this.onTap,
    this.compact = false,
  });

  final ColoringPage puzzle;
  final bool isHalloween;
  final bool isNew;
  final bool compact;
  final VoidCallback onTap;

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
                    page: puzzle,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            : ColoredBox(
                color: Colors.white.withValues(alpha: 0.95),
                child: ColoringPageImage(
                  page: puzzle,
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
      ),
    );

    final inset = compact ? 8.0 : 10.0;

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
      ],
    );
  }
}
