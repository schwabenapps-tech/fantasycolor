import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/event_catalog.dart';
import '../data/event_tags.dart';
import '../models/coloring_page.dart';
import '../providers/favorites_store.dart';
import '../screens/event_pack_gallery_screen.dart';
import '../utils/app_layout.dart';
import '../utils/app_page_route.dart';
import '../widgets/event_hub_portal.dart';

/// Galerie-Layout: Event-Hubs (Diashow) vorne → Standard-Gallery → abgelaufene Hubs hinten.
class CatalogGalleryBody extends StatelessWidget {
  const CatalogGalleryBody({
    super.key,
    required this.catalog,
    required this.tags,
    required this.coloring,
    required this.onOpenPage,
    this.gridScroll,
    this.rowScroll,
    this.showDownloadButton = false,
  });

  final GalleryCatalog catalog;
  final EventTags tags;
  final bool coloring;
  final ValueChanged<ColoringPage> onOpenPage;
  final ScrollController? gridScroll;
  final ScrollController? rowScroll;
  final bool showDownloadButton;

  List<_Entry> _entries() {
    return [
      for (final event in catalog.activeEvents) _Entry.hub(event),
      for (final page in catalog.standard.pages) _Entry.page(page),
      for (final event in catalog.pastEvents) _Entry.hub(event),
    ];
  }

  bool _isHalloween(String id) => coloring
      ? tags.isHalloweenColoring(id)
      : tags.isHalloweenPuzzle(id);

  bool _isNew(String id) {
    if (_isHalloween(id)) return false;
    return coloring ? tags.isNewColoring(id) : tags.isNewPuzzle(id);
  }

  void _openEvent(BuildContext context, GallerySection section) {
    final halloweenIds = coloring
        ? tags.halloweenColoring
        : tags.halloweenPuzzle;
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => EventPackGalleryScreen(
              section: section,
              coloring: coloring,
              halloweenIds: halloweenIds,
            ),
      ),
    );
  }

  Color _accentFor(GallerySection section) {
    if (_isHalloweenHub(section)) {
      return const Color(0xFFFF8C42);
    }
    return const Color(0xFFE8A0BF);
  }

  bool _isHalloweenHub(GallerySection section) {
    if (section.id.toLowerCase().contains('halloween')) return true;
    return section.pages.any((p) => _isHalloween(p.id));
  }

  Widget _hubTile(BuildContext context, GallerySection hub, {int index = 0}) {
    return EventHubPortal(
      title: hub.title,
      subtitle: hub.isPastEvent ? 'Archive' : null,
      imagePaths: [
        for (final p in hub.pages) p.assetPath,
      ],
      accent: _accentFor(hub),
      isHalloween: _isHalloweenHub(hub),
      slideOffset: Duration(milliseconds: 400 * index),
      onTap: () => _openEvent(context, hub),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final size = MediaQuery.sizeOf(context);
    final entries = _entries();
    if (entries.isEmpty) {
      return Center(
        child: Text(
          coloring
              ? 'No coloring pages found'
              : 'No puzzle images found',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    if (layout.isPortrait) {
      return GridView.builder(
        key: PageStorageKey<String>(
          coloring ? 'gallery_grid' : 'puzzle_grid',
        ),
        controller: gridScroll,
        scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
        padding: layout.galleryGridPadding(size).copyWith(top: 56),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: layout.galleryGridCrossAxisCount,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: layout.galleryGridChildAspectRatio,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          if (entry.hub != null) {
            return _hubTile(context, entry.hub!);
          }
          final page = entry.page!;
          return GalleryPageTile(
            page: page,
            isHalloween: _isHalloween(page.id),
            isNew: _isNew(page.id),
            compact: true,
            showDownloadButton: showDownloadButton,
            favoriteKind:
                coloring ? FavoriteKind.coloring : FavoriteKind.puzzle,
            onTap: () => onOpenPage(page),
          );
        },
      );
    }

    final tileHeight = layout.galleryTileHeight;
    return Align(
      alignment: const Alignment(0, 0.25),
      child: SizedBox(
        height: tileHeight,
        child: ListView.separated(
          key: PageStorageKey<String>(
            coloring ? 'gallery_row' : 'puzzle_row',
          ),
          controller: rowScroll,
          scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
          itemCount: entries.length,
          separatorBuilder: (_, _) => SizedBox(width: size.width * 0.03),
          itemBuilder: (context, index) {
            final entry = entries[index];
            if (entry.hub != null) {
              final hub = entry.hub!;
              // Hub etwas breiter/quadratisch wie Start-Portal.
              final hubWidth = (tileHeight * 0.92).clamp(
                tileHeight * 0.75,
                tileHeight * 1.15,
              );
              return SizedBox(
                width: hubWidth,
                height: tileHeight,
                child: _hubTile(context, hub, index: index),
              );
            }

            final page = entry.page!;
            final ratio = page.aspectRatio <= 0 ? 0.78 : page.aspectRatio;
            final pageTileWidth = (tileHeight * ratio).clamp(
              tileHeight * 0.55,
              tileHeight * 1.75,
            );
            return SizedBox(
              width: pageTileWidth,
              height: tileHeight,
              child: GalleryPageTile(
                page: page,
                isHalloween: _isHalloween(page.id),
                isNew: _isNew(page.id),
                showDownloadButton: showDownloadButton,
                favoriteKind:
                    coloring ? FavoriteKind.coloring : FavoriteKind.puzzle,
                onTap: () => onOpenPage(page),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Entry {
  const _Entry._({this.hub, this.page});

  factory _Entry.hub(GallerySection section) => _Entry._(hub: section);
  factory _Entry.page(ColoringPage page) => _Entry._(page: page);

  final GallerySection? hub;
  final ColoringPage? page;
}
