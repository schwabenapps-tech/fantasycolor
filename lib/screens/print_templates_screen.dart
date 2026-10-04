import 'dart:async';

import 'package:flutter/material.dart';

import '../data/event_catalog.dart';
import '../data/event_tags.dart';
import '../data/print_templates_loader.dart';
import '../models/coloring_page.dart';
import '../utils/app_layout.dart';
import '../utils/app_page_route.dart';
import '../widgets/catalog_gallery_body.dart';
import '../widgets/silver_back_button.dart';
import 'print_preview_screen.dart';

/// Galerie zum Speichern und Teilen von Print templates (zum Ausdrucken).
/// Halloween-Hub vorne, Standard-Druckvorlagen getrennt dahinter.
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
  late final Future<List<Object>> _loadFuture;
  final _gridScroll = ScrollController();
  final _rowScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFuture = Future.wait([
      loadPrintCatalog(),
      EventTags.load(),
      halloweenPrintTemplateIds(),
    ]);
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
    _gridScroll.dispose();
    _rowScroll.dispose();
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
                  Column(
                    children: [
                      if (layout.isLandscape)
                        SizedBox(height: layout.galleryTopSpacer * 0.15),
                      Expanded(
                        child: FutureBuilder<List<Object>>(
                          future: _loadFuture,
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
                            if (data == null || data.length < 3) {
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

                            final catalog = data[0] as GalleryCatalog;
                            final tags = data[1] as EventTags;
                            final halloweenIds = data[2] as Set<String>;

                            if (catalog.isEmpty) {
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

                            return CatalogGalleryBody(
                              catalog: catalog,
                              tags: tags,
                              kind: CatalogGalleryKind.print,
                              categoryTitle: 'Print',
                              halloweenIds: halloweenIds,
                              onOpenPage: _openPreview,
                              gridScroll: _gridScroll,
                              rowScroll: _rowScroll,
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
