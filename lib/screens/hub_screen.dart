import 'dart:async';

import 'package:flutter/material.dart';

import '../data/coloring_pages_loader.dart';
import '../data/event_catalog.dart';
import '../data/event_tags.dart';
import '../data/puzzle_images_loader.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../utils/app_layout.dart';
import '../utils/asset_precache.dart';
import '../widgets/event_hub_portal.dart';
import '../widgets/silver_back_button.dart';
import 'event_world_hub_screen.dart';
import 'favorites_screen.dart';
import 'gallery_screen.dart';
import 'print_templates_screen.dart';
import 'puzzle_gallery_screen.dart';
import 'settings_screen.dart';
import '../utils/app_page_route.dart';

/// Zentraler Einstieg: Malen / Puzzle + Druck/Favorites + Event-Hub.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

  /// Nur Standard-Gallery (keine Event-/Halloween-Bilder).
  static const malenSlideshow = <String>[
    'assets/coloring_pages/fee_clean_28.png',
    'assets/coloring_pages/fee_clean_12.png',
    'assets/coloring_pages/fee_clean_32.png',
    'assets/coloring_pages/fee_clean_01.png',
    'assets/coloring_pages/fee_clean_09.png',
    'assets/coloring_pages/fee_clean_20.png',
    'assets/coloring_pages/fee_clean_15.png',
    'assets/coloring_pages/fee_clean_27.png',
  ];

  /// Nur Standard-Puzzle-Gallery.
  static const puzzleSlideshow = <String>[
    'assets/puzzle_images/233c320c-4dd9-4fb3-8c34-af15942026cb.png',
    'assets/puzzle_images/chatgpt_image_18_sept_2026_10_26_05.png',
    'assets/puzzle_images/chatgpt_image_13_sept_2026_21_09_00.png',
    'assets/puzzle_images/chatgpt_image_18_sept_2026_09_38_35.png',
    'assets/puzzle_images/chatgpt_image_15_sept_2026_14_57_20.png',
    'assets/puzzle_images/chatgpt_image_14_sept_2026_20_51_13.png',
    'assets/puzzle_images/chatgpt_image_13_sept_2026_21_21_30.png',
    'assets/puzzle_images/a41fc2b5-8a30-4684-8560-d13fc9396cb3.png',
  ];

  /// Festes Hero-Bild für den Event-Hub (kein Slideshow).
  static const eventHubImage = 'assets/images/halloween_event_hub.jpg';

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _slideshowPrecached = false;
  Future<({GallerySection? coloring, GallerySection? puzzle, EventTags tags})>?
      _eventFuture;

  @override
  void initState() {
    super.initState();
    unawaited(AudioService.instance.startAmbient());
    _eventFuture = _loadActiveEvent();
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

  Future<({GallerySection? coloring, GallerySection? puzzle, EventTags tags})>
      _loadActiveEvent() async {
    final tags = await EventTags.load();
    final coloringCatalog = await loadColoringCatalog(shuffle: false);
    final puzzleCatalog = await loadPuzzleCatalog(shuffle: false);
    final coloring = coloringCatalog.activeEvents.isEmpty
        ? null
        : coloringCatalog.activeEvents.first;
    final puzzle = puzzleCatalog.activeEvents.isEmpty
        ? null
        : puzzleCatalog.activeEvents.first;
    // Prefer matching event ids when both exist.
    GallerySection? c = coloring;
    GallerySection? p = puzzle;
    if (c != null && p != null && c.id != p.id) {
      final match = puzzleCatalog.activeEvents.where((e) => e.id == c.id);
      if (match.isNotEmpty) p = match.first;
    }
    return (coloring: c, puzzle: p, tags: tags);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_slideshowPrecached) return;
    _slideshowPrecached = true;
    final cacheW = thumbCacheWidth(context, MediaQuery.sizeOf(context).width * 0.5);
    unawaited(
      precacheAssetImages(
        context,
        [
          ...HubScreen.malenSlideshow,
          ...HubScreen.puzzleSlideshow,
          HubScreen.eventHubImage,
        ],
        cacheWidth: cacheW,
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _open(Widget screen, {required String world}) {
    AnalyticsService.instance.logOpenWorld(world);
    AnalyticsService.instance.logScreen(world);
    Navigator.of(context).push(
      AppPageRoute<void>(
        settings: RouteSettings(name: world),
        builder: (_) => screen,
      ),
    );
  }

  void _openEventHub({
    required GallerySection coloring,
    required GallerySection puzzle,
    required EventTags tags,
  }) {
    _open(
      EventWorldHubScreen(
        title: coloring.title,
        coloringSection: coloring,
        puzzleSection: puzzle,
        halloweenIds: {
          ...tags.halloweenColoring,
          ...tags.halloweenPuzzle,
        },
      ),
      world: 'event',
    );
  }

  Widget _sideColumn({
    required double gap,
    required List<Widget> sideActions,
    required Widget? eventHub,
  }) {
    final actionsRow = SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(child: sideActions[0]),
          SizedBox(width: gap * 0.55),
          Expanded(child: sideActions[1]),
        ],
      ),
    );

    if (eventHub == null) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: actionsRow,
      );
    }

    return Column(
      children: [
        Expanded(child: eventHub),
        SizedBox(height: gap * 0.65),
        actionsRow,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final gap = size.shortestSide * 0.028;

    final worlds = [
      _WorldPortal(
        semanticLabel: 'Color',
        title: 'Color',
        imageAssets: HubScreen.malenSlideshow,
        accent: const Color(0xFFE8A0BF),
        slideOffset: Duration.zero,
        onTap: () => _open(const GalleryScreen(), world: 'malen'),
      ),
      _WorldPortal(
        semanticLabel: 'Puzzle',
        title: 'Puzzle',
        imageAssets: HubScreen.puzzleSlideshow,
        accent: const Color(0xFF7EB6E8),
        slideOffset: const Duration(milliseconds: 1600),
        onTap: () => _open(const PuzzleGalleryScreen(), world: 'puzzle'),
      ),
    ];

    final sideActions = [
      _SideAction(
        semanticLabel: 'Print',
        icon: Icons.print_rounded,
        colors: const [
          Color(0xFFF4FFF8),
          Color(0xFFD4F5E4),
          Color(0xFFA8E6C3),
        ],
        accent: const Color(0xFF2F8F5B),
        onTap: () => _open(const PrintTemplatesScreen(), world: 'drucken'),
      ),
      _SideAction(
        semanticLabel: 'Favorites',
        icon: Icons.star_rounded,
        colors: const [
          Color(0xFFFFFAF0),
          Color(0xFFFFE8A8),
          Color(0xFFFFD56A),
        ],
        accent: const Color(0xFFB8860B),
        onTap: () => _open(const FavoritesScreen(), world: 'favoriten'),
      ),
    ];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            HubScreen.backgroundAsset,
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
                      vertical: layout.hubVerticalPadding * 0.75,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: layout.isTablet ? 1100 : double.infinity,
                        ),
                        child: FutureBuilder(
                          future: _eventFuture,
                          builder: (context, snapshot) {
                            final data = snapshot.data;
                            final hasEvent = data?.coloring != null &&
                                data?.puzzle != null;
                            final eventHub = !hasEvent
                                ? null
                                : EventHubPortal(
                                    title: data!.coloring!.title,
                                    imagePaths: const [HubScreen.eventHubImage],
                                    accent: const Color(0xFFFF8C42),
                                    isHalloween: true,
                                    brightenImage: true,
                                    onTap: () => _openEventHub(
                                      coloring: data.coloring!,
                                      puzzle: data.puzzle!,
                                      tags: data.tags,
                                    ),
                                  );

                            if (layout.isPortrait) {
                              return Column(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        Expanded(child: worlds[0]),
                                        SizedBox(height: gap),
                                        Expanded(child: worlds[1]),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: gap),
                                  SizedBox(
                                    height: size.height * (hasEvent ? 0.30 : 0.10),
                                    child: _sideColumn(
                                      gap: gap,
                                      sideActions: sideActions,
                                      eventHub: eventHub,
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    children: [
                                      Expanded(child: worlds[0]),
                                      SizedBox(width: gap),
                                      Expanded(child: worlds[1]),
                                    ],
                                  ),
                                ),
                                SizedBox(width: gap * 1.1),
                                SizedBox(
                                  width: size.width *
                                      (layout.isTablet ? 0.20 : 0.22),
                                  child: _sideColumn(
                                    gap: gap,
                                    sideActions: sideActions,
                                    eventHub: eventHub,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 8,
                    right: 12,
                    child: _SettingsButton(),
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

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Settings',
      child: SilverBackButton(
        icon: Icons.settings_rounded,
        onPressed: () {
          AnalyticsService.instance.logOpenWorld('settings');
          AnalyticsService.instance.logScreen('settings');
          Navigator.of(context).push(
            AppPageRoute<void>(
        settings: const RouteSettings(name: 'settings'),
        builder: (_) => const SettingsScreen(),
      ),
          );
        },
      ),
    );
  }
}

class _WorldPortal extends StatefulWidget {
  const _WorldPortal({
    required this.semanticLabel,
    required this.title,
    required this.imageAssets,
    required this.accent,
    required this.onTap,
    this.slideOffset = Duration.zero,
  });

  final String semanticLabel;
  final String title;
  final List<String> imageAssets;
  final Color accent;
  final VoidCallback onTap;
  final Duration slideOffset;

  @override
  State<_WorldPortal> createState() => _WorldPortalState();
}

class _WorldPortalState extends State<_WorldPortal> {
  static const _slideInterval = Duration(milliseconds: 3800);
  static const _fadeDuration = Duration(milliseconds: 900);

  bool _pressed = false;
  int _index = 0;
  Timer? _timer;
  Timer? _startDelay;
  int? _portalCacheWidth;

  @override
  void initState() {
    super.initState();
    _startDelay = Timer(widget.slideOffset, _startSlideshow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _portalCacheWidth ??=
        thumbCacheWidth(context, MediaQuery.sizeOf(context).width * 0.5);
    _warmAround(_index);
  }

  void _warmAround(int index) {
    final assets = widget.imageAssets;
    if (assets.isEmpty) return;
    final cacheW = _portalCacheWidth;
    final paths = <String>{
      assets[index % assets.length],
      assets[(index + 1) % assets.length],
    };
    unawaited(precacheAssetImages(context, paths, cacheWidth: cacheW));
  }

  void _startSlideshow() {
    if (!mounted || widget.imageAssets.length < 2) return;
    _timer?.cancel();
    _timer = Timer.periodic(_slideInterval, (_) {
      if (!mounted) return;
      final next = (_index + 1) % widget.imageAssets.length;
      _warmAround(next);
      setState(() => _index = next);
    });
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = widget.imageAssets;
    final current = assets.isEmpty
        ? ''
        : assets[_index.clamp(0, assets.length - 1)];

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.88),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.4),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: _fadeDuration,
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            ...previousChildren,
                            ?currentChild,
                          ],
                        );
                      },
                      child: SizedBox.expand(
                        key: ValueKey<String>(current),
                        child: Image.asset(
                          current,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.15),
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          cacheWidth: _portalCacheWidth,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: widget.accent.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppLayout.of(context).isTablet ? 34 : 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          shadows: const [
                            Shadow(
                              color: Color(0xAA000000),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideAction extends StatefulWidget {
  const _SideAction({
    required this.semanticLabel,
    required this.icon,
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final String semanticLabel;
  final IconData icon;
  final List<Color> colors;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_SideAction> createState() => _SideActionState();
}

class _SideActionState extends State<_SideAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.colors,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                widget.icon,
                color: widget.accent,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
