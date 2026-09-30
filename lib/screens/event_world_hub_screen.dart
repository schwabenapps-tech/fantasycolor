import 'dart:async';

import 'package:flutter/material.dart';

import '../data/event_catalog.dart';
import '../utils/app_layout.dart';
import '../utils/asset_precache.dart';
import '../widgets/event_hub_portal.dart';
import '../widgets/silver_back_button.dart';
import 'event_pack_gallery_screen.dart';
import '../utils/app_page_route.dart';

/// Nach Tippen auf den Start-Event-Hub: Malen + Puzzle nur mit Event-Galleryn.
class EventWorldHubScreen extends StatefulWidget {
  const EventWorldHubScreen({
    super.key,
    required this.title,
    required this.coloringSection,
    required this.puzzleSection,
    this.halloweenIds = const {},
  });

  final String title;
  final GallerySection coloringSection;
  final GallerySection puzzleSection;
  final Set<String> halloweenIds;

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
              coloring: coloring,
              halloweenIds: widget.halloweenIds,
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

    final portals = [
      EventHubPortal(
        title: 'Color',
        subtitle: widget.title,
        imagePaths: coloringPaths,
        accent: const Color(0xFFFF8C42),
        isHalloween: true,
        onTap: () => _openPack(widget.coloringSection, coloring: true),
      ),
      EventHubPortal(
        title: 'Puzzle',
        subtitle: widget.title,
        imagePaths: puzzlePaths,
        accent: const Color(0xFF6B3FA0),
        isHalloween: true,
        slideOffset: const Duration(milliseconds: 1400),
        onTap: () => _openPack(widget.puzzleSection, coloring: false),
      ),
    ];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            EventWorldHubScreen.backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
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
                            color: const Color(0xFFFFB86B),
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
                              : Row(
                                  children: [
                                    Expanded(child: portals[0]),
                                    SizedBox(width: gap),
                                    Expanded(child: portals[1]),
                                  ],
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
