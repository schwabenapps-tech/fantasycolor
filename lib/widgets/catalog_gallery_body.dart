import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/event_catalog.dart';
import '../data/event_tags.dart';
import '../models/coloring_page.dart';
import '../providers/favorites_store.dart';
import '../screens/event_pack_gallery_screen.dart';
import '../services/event_content_gate.dart';
import '../utils/app_layout.dart';
import '../utils/app_page_route.dart';
import '../widgets/event_hub_portal.dart';
import '../widgets/gallery_category_title.dart';

enum CatalogGalleryKind { coloring, puzzle, print }

/// Galerie-Layout: Event-Hubs (Diashow) vorne → Standard-Gallery → abgelaufene Hubs hinten.
///
/// Beim Drehen wird der ungefähre sichtbare Index Grid ↔ Row mitgenommen.
class CatalogGalleryBody extends StatefulWidget {
  const CatalogGalleryBody({
    super.key,
    required this.catalog,
    required this.tags,
    required this.kind,
    required this.onOpenPage,
    this.gridScroll,
    this.rowScroll,
    this.showDownloadButton = false,
    this.categoryTitle,
    this.halloweenIds = const {},
    this.showEventHubs = true,
    this.showCategoryTitle = true,
    this.includePastEventPages = true,
  });

  final GalleryCatalog catalog;
  final EventTags tags;
  final CatalogGalleryKind kind;
  final ValueChanged<ColoringPage> onOpenPage;
  final ScrollController? gridScroll;
  final ScrollController? rowScroll;
  final bool showDownloadButton;
  /// z. B. „Color“ / „Puzzle“ / „Print“ — immer sichtbar oben in der Ansicht.
  final String? categoryTitle;
  /// Für Print: Halloween-Druckvorlagen-IDs. Sonst aus [tags] abgeleitet.
  final Set<String> halloweenIds;
  /// false = flache Kachel-Liste (keine Event-Hub-Portale).
  final bool showEventHubs;
  final bool showCategoryTitle;
  /// false = abgelaufene Event-Motive nur im Events-Tab (nicht in Malen/Puzzle).
  final bool includePastEventPages;

  @override
  State<CatalogGalleryBody> createState() => _CatalogGalleryBodyState();
}

class _CatalogGalleryBodyState extends State<CatalogGalleryBody> {
  bool? _wasPortrait;
  int _anchorIndex = 0;

  List<_Entry> _entries() {
    if (!widget.showEventHubs) {
      final byId = <String, ColoringPage>{};
      for (final event in widget.catalog.activeEvents) {
        for (final page in event.pages) {
          byId[page.id] = page;
        }
      }
      for (final page in widget.catalog.standard.pages) {
        byId[page.id] = page;
      }
      if (widget.includePastEventPages) {
        for (final event in widget.catalog.pastEvents) {
          for (final page in event.pages) {
            byId.putIfAbsent(page.id, () => page);
          }
        }
      }
      final coloring = widget.kind == CatalogGalleryKind.coloring;
      final sorted = widget.tags.sortNewestFirst(
        byId.values.toList(),
        coloring: coloring,
      );
      return [for (final page in sorted) _Entry.page(page)];
    }
    // Reihenfolge kommt aus buildCatalog: Neu → Featured → Rest.
    return [
      for (final event in widget.catalog.activeEvents) _Entry.hub(event),
      for (final page in widget.catalog.standard.pages) _Entry.page(page),
      for (final event in widget.catalog.pastEvents) _Entry.hub(event),
    ];
  }

  bool _requiresAdUnlock(String id) {
    if (widget.kind == CatalogGalleryKind.print) return true;
    return EventContentGate.isGatedId(
      widget.tags,
      id,
      kind: widget.kind == CatalogGalleryKind.puzzle
          ? FavoriteKind.puzzle
          : FavoriteKind.coloring,
    );
  }

  Set<String> get _halloweenIds {
    if (widget.halloweenIds.isNotEmpty) return widget.halloweenIds;
    return switch (widget.kind) {
      CatalogGalleryKind.coloring => widget.tags.halloweenColoring,
      CatalogGalleryKind.puzzle => widget.tags.halloweenPuzzle,
      CatalogGalleryKind.print => const {},
    };
  }

  bool _isHalloween(String id) => _halloweenIds.contains(id);

  bool _isNew(String id) {
    return switch (widget.kind) {
      CatalogGalleryKind.coloring => widget.tags.isNewColoring(id),
      CatalogGalleryKind.puzzle => widget.tags.isNewPuzzle(id),
      CatalogGalleryKind.print => false,
    };
  }

  void _openEvent(BuildContext context, GallerySection section) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => EventPackGalleryScreen(
          section: section,
          kind: widget.kind,
          halloweenIds: _halloweenIds,
          tags: widget.tags,
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
      brightenImage: true,
      slideOffset: Duration(milliseconds: 400 * index),
      onTap: () => _openEvent(context, hub),
    );
  }

  String get _storageKey => switch (widget.kind) {
        CatalogGalleryKind.coloring => 'gallery',
        CatalogGalleryKind.puzzle => 'puzzle',
        CatalogGalleryKind.print => 'print',
      };

  FavoriteKind get _favoriteKind => switch (widget.kind) {
        CatalogGalleryKind.coloring => FavoriteKind.coloring,
        CatalogGalleryKind.puzzle => FavoriteKind.puzzle,
        CatalogGalleryKind.print => FavoriteKind.coloring,
      };

  bool get _showFavoriteButton => widget.kind != CatalogGalleryKind.print;

  double _rowExtent(_Entry entry, double tileHeight) {
    if (entry.hub != null) {
      return (tileHeight * 0.92).clamp(tileHeight * 0.75, tileHeight * 1.15);
    }
    final page = entry.page!;
    final ratio = page.aspectRatio <= 0 ? 0.78 : page.aspectRatio;
    return (tileHeight * ratio).clamp(tileHeight * 0.55, tileHeight * 1.75);
  }

  int _indexFromGrid({
    required AppLayout layout,
    required Size size,
    required int itemCount,
  }) {
    final c = widget.gridScroll;
    if (c == null || !c.hasClients || itemCount <= 0) return _anchorIndex;
    final pad = layout.galleryGridPadding(size).copyWith(top: 8);
    final cols = layout.galleryGridCrossAxisCount;
    final usableW =
        (size.width - pad.left - pad.right).clamp(1.0, double.infinity);
    const spacing = 14.0;
    final cellW = (usableW - spacing * (cols - 1)) / cols;
    final cellH = cellW / layout.galleryGridChildAspectRatio;
    final rowH = cellH + spacing;
    final row = ((c.offset - pad.top).clamp(0.0, double.infinity) / rowH)
        .floor();
    return (row * cols).clamp(0, itemCount - 1);
  }

  int _indexFromRow({
    required AppLayout layout,
    required Size size,
    required List<_Entry> entries,
  }) {
    final c = widget.rowScroll;
    if (c == null || !c.hasClients || entries.isEmpty) return _anchorIndex;
    final tileH = layout.galleryTileHeight;
    final sep = size.width * 0.03;
    final pad = size.width * 0.05;
    var x = pad;
    final target = c.offset + size.width * 0.15;
    for (var i = 0; i < entries.length; i++) {
      final w = _rowExtent(entries[i], tileH);
      if (x + w >= target) return i;
      x += w + sep;
    }
    return entries.length - 1;
  }

  void _jumpToGrid({
    required AppLayout layout,
    required Size size,
    required int index,
    required int itemCount,
  }) {
    final c = widget.gridScroll;
    if (c == null || !c.hasClients || itemCount <= 0) return;
    final pad = layout.galleryGridPadding(size).copyWith(top: 8);
    final cols = layout.galleryGridCrossAxisCount;
    final usableW =
        (size.width - pad.left - pad.right).clamp(1.0, double.infinity);
    const spacing = 14.0;
    final cellW = (usableW - spacing * (cols - 1)) / cols;
    final cellH = cellW / layout.galleryGridChildAspectRatio;
    final rowH = cellH + spacing;
    final row = index ~/ cols;
    final target = (pad.top + row * rowH)
        .clamp(0.0, c.position.maxScrollExtent);
    c.jumpTo(target);
  }

  void _jumpToRow({
    required AppLayout layout,
    required Size size,
    required List<_Entry> entries,
    required int index,
  }) {
    final c = widget.rowScroll;
    if (c == null || !c.hasClients || entries.isEmpty) return;
    final tileH = layout.galleryTileHeight;
    final sep = size.width * 0.03;
    final pad = size.width * 0.05;
    var x = pad;
    final i = index.clamp(0, entries.length - 1);
    for (var n = 0; n < i; n++) {
      x += _rowExtent(entries[n], tileH) + sep;
    }
    c.jumpTo(x.clamp(0.0, c.position.maxScrollExtent));
  }

  void _syncAfterOrientationChange({
    required bool toPortrait,
    required AppLayout layout,
    required Size size,
    required List<_Entry> entries,
  }) {
    final index = _anchorIndex.clamp(0, entries.isEmpty ? 0 : entries.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Zweiter Frame: neuer Controller ist oft erst dann attached.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (toPortrait) {
          _jumpToGrid(
            layout: layout,
            size: size,
            index: index,
            itemCount: entries.length,
          );
        } else {
          _jumpToRow(
            layout: layout,
            size: size,
            entries: entries,
            index: index,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final size = MediaQuery.sizeOf(context);
    final entries = _entries();
    final portrait = layout.isPortrait;
    final title = (widget.categoryTitle ??
            switch (widget.kind) {
              CatalogGalleryKind.coloring => 'Color',
              CatalogGalleryKind.puzzle => 'Puzzle',
              CatalogGalleryKind.print => 'Print',
            })
        .trim();

    if (_wasPortrait != null && _wasPortrait != portrait && entries.isNotEmpty) {
      // _anchorIndex kommt aus den vorherigen Frames derselben Orientierung.
      _syncAfterOrientationChange(
        toPortrait: portrait,
        layout: layout,
        size: size,
        entries: entries,
      );
    } else if (entries.isNotEmpty) {
      // Laufend merken, solange dieselbe Orientierung gilt.
      if (portrait && widget.gridScroll?.hasClients == true) {
        _anchorIndex = _indexFromGrid(
          layout: layout,
          size: size,
          itemCount: entries.length,
        );
      } else if (!portrait && widget.rowScroll?.hasClients == true) {
        _anchorIndex = _indexFromRow(
          layout: layout,
          size: size,
          entries: entries,
        );
      }
    }
    _wasPortrait = portrait;

    if (entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GalleryCategoryTitle(title: title),
          const Expanded(
            child: Center(
              child: Text(
                'No images found',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ),
        ],
      );
    }

    final gallery = portrait
        ? GridView.builder(
            key: PageStorageKey<String>('${_storageKey}_grid'),
            controller: widget.gridScroll,
            scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
            padding: layout.galleryGridPadding(size).copyWith(top: 8),
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
                showDownloadButton: widget.showDownloadButton,
                showFavoriteButton: _showFavoriteButton,
                favoriteKind: _favoriteKind,
                requiresAdUnlock: _requiresAdUnlock(page.id),
                onTap: () => widget.onOpenPage(page),
              );
            },
          )
        : Align(
            alignment: const Alignment(0, 0.2),
            child: SizedBox(
              height: layout.galleryTileHeight,
              child: ListView.separated(
                key: PageStorageKey<String>('${_storageKey}_row'),
                controller: widget.rowScroll,
                scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
                itemCount: entries.length,
                separatorBuilder: (_, _) => SizedBox(width: size.width * 0.03),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  if (entry.hub != null) {
                    final hub = entry.hub!;
                    final tileHeight = layout.galleryTileHeight;
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
                  final tileHeight = layout.galleryTileHeight;
                  final ratio =
                      page.aspectRatio <= 0 ? 0.78 : page.aspectRatio;
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
                      showDownloadButton: widget.showDownloadButton,
                      showFavoriteButton: _showFavoriteButton,
                      favoriteKind: _favoriteKind,
                      requiresAdUnlock: _requiresAdUnlock(page.id),
                      onTap: () => widget.onOpenPage(page),
                    ),
                  );
                },
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showCategoryTitle) GalleryCategoryTitle(title: title),
        Expanded(child: gallery),
      ],
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
