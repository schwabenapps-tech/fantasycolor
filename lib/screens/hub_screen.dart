import 'package:flutter/material.dart';

import '../utils/app_layout.dart';
import 'favorites_screen.dart';
import 'gallery_screen.dart';
import 'print_templates_screen.dart';
import 'puzzle_gallery_screen.dart';

/// Zentraler Einstieg: zwei große Welten (Malen / Puzzle) + kleine Nebenaktionen.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

  static const _malenPreview = 'assets/coloring_pages/fee_clean_34.png';
  static const _puzzlePreview =
      'assets/puzzle_images/chatgpt_image_24_sept_2026_09_34_55.png';

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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

  void _open(Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
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
        imageAsset: HubScreen._malenPreview,
        accent: const Color(0xFFE8A0BF),
        onTap: () => _open(const GalleryScreen()),
      ),
      _WorldPortal(
        semanticLabel: 'Puzzle',
        title: 'Puzzle',
        imageAsset: HubScreen._puzzlePreview,
        accent: const Color(0xFF7EB6E8),
        onTap: () => _open(const PuzzleGalleryScreen()),
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
        onTap: () => _open(const PrintTemplatesScreen()),
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
        onTap: () => _open(const FavoritesScreen()),
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
              child: Padding(
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
                                width: size.width * (layout.isTablet ? 0.12 : 0.14),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldPortal extends StatefulWidget {
  const _WorldPortal({
    required this.semanticLabel,
    required this.title,
    required this.imageAsset,
    required this.accent,
    required this.onTap,
  });

  final String semanticLabel;
  final String title;
  final String imageAsset;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_WorldPortal> createState() => _WorldPortalState();
}

class _WorldPortalState extends State<_WorldPortal> {
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
                  Image.asset(
                    widget.imageAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: widget.accent.withValues(alpha: 0.35),
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
