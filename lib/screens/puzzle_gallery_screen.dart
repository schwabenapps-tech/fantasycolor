import 'dart:async';

import 'package:flutter/material.dart';

import '../data/event_catalog.dart';
import '../data/event_tags.dart';
import '../data/puzzle_images_loader.dart';
import '../models/coloring_page.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/remote_pack_service.dart';
import '../utils/app_layout.dart';
import '../utils/asset_precache.dart';
import '../widgets/catalog_gallery_body.dart';
import '../widgets/silver_back_button.dart';
import 'puzzle_screen.dart';
import '../utils/app_page_route.dart';

/// Galerie zur Auswahl der Puzzle-Bilder — Event-Hubs vorne, Standard getrennt.
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
  Future<GalleryCatalog>? _catalogFuture;
  Future<EventTags>? _tagsFuture;
  bool _thumbsPrecached = false;
  int _heardGeneration = -1;

  @override
  void initState() {
    super.initState();
    _reloadFutures();
    _heardGeneration = RemotePackService.instance.generation;
    RemotePackService.instance.addListener(_onRemoteChanged);
    unawaited(AudioService.instance.startAmbient());
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

  void _onRemoteChanged() {
    final gen = RemotePackService.instance.generation;
    if (!mounted || gen == _heardGeneration) return;
    _heardGeneration = gen;
    setState(_reloadFutures);
  }

  void _reloadFutures() {
    _catalogFuture = loadPuzzleCatalog();
    _tagsFuture = EventTags.load();
    _thumbsPrecached = false;
  }

  void _precacheThumbs(List<ColoringPage> puzzles) {
    if (_thumbsPrecached || puzzles.isEmpty) return;
    _thumbsPrecached = true;
    final cacheW = thumbCacheWidth(
      context,
      MediaQuery.sizeOf(context).shortestSide * 0.42,
    );
    unawaited(
      precacheAssetImages(
        context,
        puzzles.map((p) => p.assetPath),
        cacheWidth: cacheW,
      ),
    );
  }

  @override
  void dispose() {
    RemotePackService.instance.removeListener(_onRemoteChanged);
    _fadeController.dispose();
    super.dispose();
  }

  void _openPuzzle(ColoringPage puzzle) {
    AnalyticsService.instance.logStartPuzzle(puzzle.id);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PuzzleScreen(puzzle: puzzle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);

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
                  Column(
                    children: [
                      if (layout.isLandscape)
                        SizedBox(height: layout.puzzleGalleryTopSpacer * 0.15),
                      Expanded(
                        child: FutureBuilder<List<Object>>(
                          key: ValueKey('puzzle_catalog_$_heardGeneration'),
                          future: Future.wait([
                            _catalogFuture!,
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
                            final catalog = data == null
                                ? const GalleryCatalog(
                                    activeEvents: [],
                                    standard: GallerySection(
                                      id: 'standard',
                                      title: 'Gallery',
                                      pages: [],
                                    ),
                                    pastEvents: [],
                                  )
                                : data[0] as GalleryCatalog;
                            final tags = data == null
                                ? null
                                : data[1] as EventTags;
                            if (catalog.isEmpty || tags == null) {
                              return const Center(
                                child: Text(
                                  'No puzzle images found',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }

                            _precacheThumbs(catalog.allPages);

                            return CatalogGalleryBody(
                              catalog: catalog,
                              tags: tags,
                              coloring: false,
                              categoryTitle: 'Puzzle',
                              showDownloadButton: true,
                              onOpenPage: _openPuzzle,
                            );
                          },
                        ),
                      ),
                      if (layout.isLandscape)
                        SizedBox(height: size.height * 0.02),
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
