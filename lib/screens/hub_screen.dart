import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_service.dart';
import '../services/analytics_service.dart';
import '../utils/app_layout.dart';
import '../utils/asset_precache.dart';
import 'favorites_screen.dart';
import 'gallery_screen.dart';
import 'print_templates_screen.dart';
import 'puzzle_gallery_screen.dart';

/// Zentraler Einstieg: zwei große Welten (Malen / Puzzle) + kleine Nebenaktionen.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

  /// Diashow: eher quadratisch/hochkant, damit Cover im Portal ohne Ränder sitzt.
  static const malenSlideshow = <String>[
    'assets/coloring_pages/fee_clean_38.png', // 1:1
    'assets/coloring_pages/fee_clean_28.png', // hochkant
    'assets/coloring_pages/fee_clean_12.png', // hochkant
    'assets/coloring_pages/fee_clean_37.png', // leicht quer
    'assets/coloring_pages/fee_clean_36.png',
    'assets/coloring_pages/fee_clean_32.png',
    'assets/coloring_pages/fee_clean_33.png',
    'assets/coloring_pages/fee_clean_35.png',
  ];

  /// Puzzle-Diashow: gleiche Idee — starkes Querformat vermeiden.
  static const puzzleSlideshow = <String>[
    'assets/puzzle_images/7ff08153-2c3e-465e-814f-df41d674f49e.png', // 1:1
    'assets/puzzle_images/a93a657b-db82-472a-b9a7-d8898f88ef96.png', // hochkant
    'assets/puzzle_images/chatgpt_image_18_sept_2026_10_26_05.png',
    'assets/puzzle_images/chatgpt_image_13_sept_2026_21_09_00.png',
    'assets/puzzle_images/chatgpt_image_24_sept_2026_09_34_55.png',
    'assets/puzzle_images/chatgpt_image_24_sept_2026_10_27_54.png',
    'assets/puzzle_images/chatgpt_image_24_sept_2026_11_00_48.png',
    'assets/puzzle_images/chatgpt-bild_27_sept_2026_00_35_51.png',
  ];

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _slideshowPrecached = false;

  @override
  void initState() {
    super.initState();
    // Musik hier nochmal anstoßen — überlebt Hot-Reload und Mute-Races.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_slideshowPrecached) return;
    _slideshowPrecached = true;
    // Diashow-Motive vorab dekodieren — sonst erscheinen sie erst beim Wechsel.
    final cacheW = thumbCacheWidth(context, MediaQuery.sizeOf(context).width * 0.5);
    unawaited(
      precacheAssetImages(
        context,
        [...HubScreen.malenSlideshow, ...HubScreen.puzzleSlideshow],
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
      PageRouteBuilder<void>(
        settings: RouteSettings(name: world),
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(opacity: animation, child: screen);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final gap = size.shortestSide * 0.028;

    final worlds = [
      _WorldPortal(
        semanticLabel: 'Malen',
        title: 'Malen',
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
        semanticLabel: 'Drucken',
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
        semanticLabel: 'Favoriten',
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
                        child: layout.isPortrait
                            ? Column(
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
                                    height: size.height * 0.12,
                                    child: Row(
                                      children: [
                                        Expanded(child: sideActions[0]),
                                        SizedBox(width: gap),
                                        Expanded(child: sideActions[1]),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Row(
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
                                        (layout.isTablet ? 0.12 : 0.14),
                                    child: Column(
                                      children: [
                                        Expanded(child: sideActions[0]),
                                        SizedBox(height: gap),
                                        Expanded(child: sideActions[1]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 8,
                    right: 12,
                    child: _MusicMuteButton(),
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

class _MusicMuteButton extends StatelessWidget {
  const _MusicMuteButton();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioService>();
    final muted = audio.muted;
    return Semantics(
      button: true,
      label: muted ? 'Musik einschalten' : 'Musik ausschalten',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          unawaited(audio.toggleMuted());
          AnalyticsService.instance.logMuteToggled(muted: !audio.muted);
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF6E8),
                Color(0xFFE8C9A0),
                Color(0xFFC9A06A),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC9A06A).withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFF3A2810),
                    size: 24,
                  ),
                  if (muted)
                    Transform.rotate(
                      angle: -math.pi / 4,
                      child: Container(
                        width: 28,
                        height: 2.8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A2810),
                          borderRadius: BorderRadius.circular(2),
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
    // Erstes + nächstes Motiv sofort warmhalten.
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
                  // AnimatedSwitcher sonst auf Intrinsic-Size → Ränder bei Landscape.
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
          duration: const Duration(milliseconds: 120),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.colors,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: AppLayout.of(context).isTablet ? 42 : 34,
                color: widget.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
