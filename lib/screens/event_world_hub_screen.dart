import 'dart:async';

import 'package:flutter/material.dart';

import '../data/event_catalog.dart';
import '../data/event_tags.dart';
import '../utils/app_layout.dart';
import '../utils/asset_precache.dart';
import '../widgets/catalog_gallery_body.dart';
import '../widgets/event_hub_portal.dart';
import '../widgets/silver_back_button.dart';
import '../widgets/winter_atmosphere_overlay.dart';
import 'event_pack_gallery_screen.dart';
import '../utils/app_page_route.dart';

/// Nach Tippen auf den Start-Event-Hub: Malen + Puzzle nur mit Event-Galleryn.
class EventWorldHubScreen extends StatefulWidget {
  const EventWorldHubScreen({
    super.key,
    required this.title,
    required this.coloringSection,
    required this.puzzleSection,
    this.isHalloween = false,
    this.halloweenIds = const {},
    this.tags,
  });

  final String title;
  final GallerySection coloringSection;
  final GallerySection puzzleSection;
  final bool isHalloween;
  final Set<String> halloweenIds;
  final EventTags? tags;

  static const backgroundAsset = 'assets/images/in_app_background.png';

  @override
  State<EventWorldHubScreen> createState() => _EventWorldHubScreenState();
}

class _EventWorldHubScreenState extends State<EventWorldHubScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    final size = MediaQuery.sizeOf(context);
    unawaited(
      precacheAssetImages(
        context,
        [
          for (final p in widget.coloringSection.pages.take(4)) p.assetPath,
          for (final p in widget.puzzleSection.pages.take(4)) p.assetPath,
        ],
        cacheWidth: thumbCacheWidth(context, size.width * 0.45),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _openPack(GallerySection section, {required bool coloring}) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => EventPackGalleryScreen(
              section: section,
              kind: coloring
                  ? CatalogGalleryKind.coloring
                  : CatalogGalleryKind.puzzle,
              halloweenIds: widget.halloweenIds,
              tags: widget.tags,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final gap = size.shortestSide * 0.028;
    final coloringPaths = [
      for (final p in widget.coloringSection.pages) p.assetPath,
    ];
    final puzzlePaths = [
      for (final p in widget.puzzleSection.pages) p.assetPath,
    ];

    final accent = widget.isHalloween
        ? const Color(0xFFFF8C42)
        : const Color(0xFFE8A0BF);
    final portals = [
      EventHubPortal(
        title: 'Color',
        subtitle: widget.title,
        imagePaths: coloringPaths,
        accent: accent,
        isHalloween: widget.isHalloween,
        // Halloween blieb aufgehellt; Winter/Christmas normale Diaschau.
        brightenImage: widget.isHalloween,
        onTap: () => _openPack(widget.coloringSection, coloring: true),
      ),
      EventHubPortal(
        title: 'Puzzle',
        subtitle: widget.title,
        imagePaths: puzzlePaths,
        accent: widget.isHalloween
            ? const Color(0xFF6B3FA0)
            : const Color(0xFF7EC8E3),
        isHalloween: widget.isHalloween,
        brightenImage: widget.isHalloween,
        slideOffset: const Duration(milliseconds: 1400),
        onTap: () => _openPack(widget.puzzleSection, coloring: false),
      ),
    ];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const WinterHubBackdrop(
            fallbackAsset: EventWorldHubScreen.backgroundAsset,
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.hubHorizontalPadding * 0.85,
                      vertical: layout.hubVerticalPadding * 0.7,
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: widget.isHalloween
                                ? const Color(0xFFFFB86B)
                                : const Color(0xFFFFE7A0),
                            fontSize: layout.isTablet ? 32 : 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: layout.isPortrait
                              ? Column(
                                  children: [
                                    Expanded(child: portals[0]),
                                    SizedBox(height: gap),
                                    Expanded(child: portals[1]),
                                  ],
                                )
                              : Align(
                                  // Landscape: gleiche feste Kachelhöhe wie Galerie,
                                  // Color + Puzzle nebeneinander (seitlich).
                                  alignment: const Alignment(0, 0.15),
                                  child: Builder(
                                    builder: (context) {
                                      final tileH = layout.galleryTileHeight;
                                      final hubW = (tileH * 0.92).clamp(
                                        tileH * 0.78,
                                        tileH * 1.12,
                                      );
                                      return SizedBox(
                                        height: tileH,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: hubW,
                                              height: tileH,
                                              child: portals[0],
                                            ),
                                            SizedBox(width: gap),
                                            SizedBox(
                                              width: hubW,
                                              height: tileH,
                                              child: portals[1],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
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
