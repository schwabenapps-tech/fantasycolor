import 'package:flutter/material.dart';

import '../data/print_templates_loader.dart';
import '../models/coloring_page.dart';
import '../utils/app_layout.dart';
import '../widgets/silver_back_button.dart';
import 'print_preview_screen.dart';
import '../utils/app_page_route.dart';

/// Galerie zum Speichern und Teilen von Print templates (zum Ausdrucken).
class PrintTemplatesScreen extends StatefulWidget {
  const PrintTemplatesScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

  @override
  State<PrintTemplatesScreen> createState() => _PrintTemplatesScreenState();
}

class _PrintTemplatesScreenState extends State<PrintTemplatesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Future<List<ColoringPage>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = loadPrintTemplates(shuffle: false);
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

  void _openPreview(ColoringPage page) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PrintPreviewScreen(page: page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final tileHeight = layout.galleryTileHeight;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            PrintTemplatesScreen.backgroundAsset,
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
                            'No templates found',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          SizedBox(
                            height: layout.isPortrait
                                ? 52
                                : layout.galleryTopSpacer,
                          ),
                          Text(
                            'Print templates',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              shadows: const [
                                Shadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap an image for preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              shadows: const [
                                Shadow(
                                  color: Color(0xCC000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 1),
                                ),
                                Shadow(
                                  color: Color(0x88000000),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: layout.isPortrait
                                ? GridView.builder(
                                    padding: layout.galleryGridPadding(size),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount:
                                          layout.galleryGridCrossAxisCount,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      childAspectRatio:
                                          layout.galleryGridChildAspectRatio,
                                    ),
                                    itemCount: pages.length,
                                    itemBuilder: (context, index) {
                                      final page = pages[index];
                                      return _PrintTemplateTile(
                                        page: page,
                                        fillPreview: true,
                                        onTap: () => _openPreview(page),
                                      );
                                    },
                                  )
                                : Align(
                                    alignment: const Alignment(0, 0.35),
                                    child: SizedBox(
                                      height: tileHeight,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: size.width * 0.055,
                                        ),
                                        itemCount: pages.length,
                                        separatorBuilder: (_, _) =>
                                            SizedBox(width: size.width * 0.03),
                                        itemBuilder: (context, index) {
                                          final page = pages[index];
                                          final ratio = page.aspectRatio <= 0
                                              ? 0.78
                                              : page.aspectRatio;
                                          final pageTileWidth =
                                              (tileHeight * ratio).clamp(
                                            tileHeight * 0.55,
                                            tileHeight * 1.75,
                                          );
                                          return SizedBox(
                                            width: pageTileWidth,
                                            height: tileHeight,
                                            child: _PrintTemplateTile(
                                              page: page,
                                              onTap: () => _openPreview(page),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                          ),
                          if (layout.isLandscape)
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

class _PrintTemplateTile extends StatelessWidget {
  const _PrintTemplateTile({
    required this.page,
    required this.onTap,
    this.fillPreview = false,
  });

  final ColoringPage page;
  final VoidCallback onTap;
  final bool fillPreview;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ColoredBox(
                    color: Colors.white,
                    child: Image.asset(
                      page.assetPath,
                      fit: fillPreview ? BoxFit.cover : BoxFit.contain,
                      alignment: const Alignment(0, -0.12),
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2A44).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_rounded,
                          color: Color(0xFFE8EEF8),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Preview',
                          style: TextStyle(
                            color: Color(0xFFE8EEF8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }
}
