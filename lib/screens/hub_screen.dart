import 'package:flutter/material.dart';

import 'favorites_screen.dart';
import 'gallery_screen.dart';
import 'print_templates_screen.dart';
import 'puzzle_gallery_screen.dart';

/// Zentraler Einstieg nach dem Start-Screen: Malen, Puzzle, Drucken, Favoriten.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

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
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.08),
                  Text(
                    'Was möchtest du machen?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      shadows: const [
                        Shadow(
                          color: Color(0xAA000000),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.06),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.08,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _HubModeCard(
                              label: 'Malen',
                              subtitle: 'Ausmalbilder',
                              icon: Icons.brush_rounded,
                              colors: const [
                                Color(0xFFFFF7FB),
                                Color(0xFFE9D7FF),
                                Color(0xFFD4B8F5),
                              ],
                              accent: const Color(0xFF6B4FA0),
                              onTap: () => _open(const GalleryScreen()),
                            ),
                          ),
                          SizedBox(width: size.width * 0.03),
                          Expanded(
                            child: _HubModeCard(
                              label: 'Puzzle',
                              subtitle: 'Puzzles legen',
                              icon: Icons.extension_rounded,
                              colors: const [
                                Color(0xFFF7FBFF),
                                Color(0xFFD7ECFF),
                                Color(0xFFB8DAF5),
                              ],
                              accent: const Color(0xFF3F6FA0),
                              onTap: () => _open(const PuzzleGalleryScreen()),
                            ),
                          ),
                          SizedBox(width: size.width * 0.03),
                          Expanded(
                            child: _HubModeCard(
                              label: 'Drucken',
                              subtitle: 'Vorlagen',
                              icon: Icons.print_rounded,
                              colors: const [
                                Color(0xFFF4FFF8),
                                Color(0xFFD4F5E4),
                                Color(0xFFA8E6C3),
                              ],
                              accent: const Color(0xFF2F8F5B),
                              onTap: () => _open(const PrintTemplatesScreen()),
                            ),
                          ),
                          SizedBox(width: size.width * 0.03),
                          Expanded(
                            child: _HubModeCard(
                              label: 'Favoriten',
                              subtitle: 'Gemerkte Bilder',
                              icon: Icons.star_rounded,
                              colors: const [
                                Color(0xFFFFFAF0),
                                Color(0xFFFFE8A8),
                                Color(0xFFFFD56A),
                              ],
                              accent: const Color(0xFFB8860B),
                              onTap: () => _open(const FavoritesScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.06),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubModeCard extends StatefulWidget {
  const _HubModeCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_HubModeCard> createState() => _HubModeCardState();
}

class _HubModeCardState extends State<_HubModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
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
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 48, color: widget.accent),
                  const SizedBox(height: 14),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.accent.withValues(alpha: 0.95),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.accent.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
