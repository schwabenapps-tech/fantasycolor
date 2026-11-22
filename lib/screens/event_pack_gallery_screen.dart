import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/event_catalog.dart';
import '../data/event_tags.dart';
import '../models/coloring_page.dart';
import '../l10n/app_strings.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/favorites_store.dart';
import '../providers/star_wallet_store.dart';
import '../screens/favorites_screen.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/event_content_gate.dart';
import '../services/star_content_gate.dart';
import '../utils/app_layout.dart';
import '../utils/app_page_route.dart';
import '../widgets/catalog_gallery_body.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/event_badges.dart';
import '../widgets/gallery_category_title.dart';
import '../widgets/progress_badge.dart';
import '../widgets/puzzle_preview_overlay.dart';
import '../widgets/silver_back_button.dart';
import '../widgets/winter_atmosphere_overlay.dart';
import 'coloring_preview_screen.dart';
import 'print_preview_screen.dart';
import 'puzzle_screen.dart';

/// Galerie nur für ein Event-Pack (nach Tippen auf den Event-Hub).
class EventPackGalleryScreen extends StatelessWidget {
  const EventPackGalleryScreen({
    super.key,
    required this.section,
    required this.kind,
    this.halloweenIds = const {},
    this.tags,
  });

  final GallerySection section;
  final CatalogGalleryKind kind;
  final Set<String> halloweenIds;
  final EventTags? tags;

  static const backgroundAsset = 'assets/images/in_app_background.png';

  bool get _coloring => kind == CatalogGalleryKind.coloring;
  bool get _print => kind == CatalogGalleryKind.print;

  bool _isNew(String id) {
    final t = tags;
    if (t == null || _print) return false;
    return _coloring ? t.isNewColoring(id) : t.isNewPuzzle(id);
  }

  bool _requiresAdUnlock(String id) {
    // Druckvorlagen: jedes Öffnen braucht Werbung.
    if (_print) return true;
    final t = tags;
    if (t == null) return false;
    return EventContentGate.isGatedId(
      t,
      id,
      kind: _coloring ? FavoriteKind.coloring : FavoriteKind.puzzle,
    );
  }

  int? _starLockCost(BuildContext context, String id) {
    if (_print) return null;
    final kind =
        _coloring ? FavoriteKind.coloring : FavoriteKind.puzzle;
    final wallet = context.watch<StarWalletStore>();
    if (!wallet.requiresStars(id, kind)) return null;
    return wallet.unlockCost(id, kind);
  }

  Future<void> _open(BuildContext context, ColoringPage page) async {
    switch (kind) {
      case CatalogGalleryKind.coloring:
        final ok = await StarContentGate.ensureUnlocked(
          context,
          id: page.id,
          kind: FavoriteKind.coloring,
        );
        if (!ok || !context.mounted) return;
        AnalyticsService.instance.logStartColoring(page.id);
        await Navigator.of(context).push(
          AppPageRoute<void>(
            builder: (_) => ColoringPreviewScreen(page: page),
          ),
        );
      case CatalogGalleryKind.puzzle:
        final ok = await StarContentGate.ensureUnlocked(
          context,
          id: page.id,
          kind: FavoriteKind.puzzle,
        );
        if (!ok || !context.mounted) return;
        AnalyticsService.instance.logStartPuzzle(page.id);
        await Navigator.of(context).push(
          AppPageRoute<void>(
            builder: (_) => PuzzleScreen(puzzle: page),
          ),
        );
      case CatalogGalleryKind.print:
        await AdsService.showPrintTemplateInterstitial();
        if (!context.mounted) return;
        await Navigator.of(context).push(
          AppPageRoute<void>(
            builder: (_) => PrintPreviewScreen(page: page),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final pages = section.pages;
    final tileHeight = layout.galleryTileHeight;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          WinterHubBackdrop(fallbackAsset: backgroundAsset),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    GalleryCategoryTitle(
                      title: switch (kind) {
                        CatalogGalleryKind.coloring => 'Color',
                        CatalogGalleryKind.puzzle => 'Puzzle',
                        CatalogGalleryKind.print => 'Print',
                      },
                      subtitle: section.title,
                      accentColor: section.isPastEvent
                          ? const Color(0xFFB8C0D4)
                          : const Color(0xFFFFB86B),
                    ),
                    Expanded(
                      child: pages.isEmpty
                          ? const Center(
                              child: Text(
                                'No images in this event',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : layout.isPortrait
                              ? GridView.builder(
                                  padding: layout
                                      .galleryGridPadding(size)
                                      .copyWith(top: 8),
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
                                    return GalleryPageTile(
                                      page: page,
                                      isHalloween:
                                          halloweenIds.contains(page.id),
                                      isNew: _isNew(page.id),
                                      compact: true,
                                      showPreviewButton:
                                          kind == CatalogGalleryKind.puzzle,
                                      showFavoriteButton: !_print,
                                      favoriteKind: _coloring
                                          ? FavoriteKind.coloring
                                          : FavoriteKind.puzzle,
                                      requiresAdUnlock:
                                          _requiresAdUnlock(page.id),
                                      starLockCost:
                                          _starLockCost(context, page.id),
                                      onTap: () => _open(context, page),
                                    );
                                  },
                                )
                              : Align(
                                  alignment: const Alignment(0, 0.2),
                                  child: SizedBox(
                                    height: tileHeight,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: size.width * 0.05,
                                      ),
                                      itemCount: pages.length,
                                      separatorBuilder: (_, _) =>
                                          SizedBox(width: size.width * 0.03),
                                      itemBuilder: (context, index) {
                                        final page = pages[index];
                                        final ratio = page.aspectRatio <= 0
                                            ? 0.78
                                            : page.aspectRatio;
                                        final w = (tileHeight * ratio).clamp(
                                          tileHeight * 0.55,
                                          tileHeight * 1.75,
                                        );
                                        return SizedBox(
                                          width: w,
                                          height: tileHeight,
                                          child: GalleryPageTile(
                                            page: page,
                                            isHalloween: halloweenIds
                                                .contains(page.id),
                                            isNew: _isNew(page.id),
                                            showPreviewButton: kind ==
                                                CatalogGalleryKind.puzzle,
                                            showFavoriteButton: !_print,
                                            favoriteKind: _coloring
                                                ? FavoriteKind.coloring
                                                : FavoriteKind.puzzle,
                                            requiresAdUnlock:
                                                _requiresAdUnlock(page.id),
                                            starLockCost: _starLockCost(
                                              context,
                                              page.id,
                                            ),
                                            onTap: () =>
                                                _open(context, page),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                    ),
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
        ],
      ),
    );
  }
}

/// Gemeinsame Vorschaukachel (Ausmalen / Puzzle / Event-Pack).
class GalleryPageTile extends StatelessWidget {
  const GalleryPageTile({
    super.key,
    required this.page,
    required this.isHalloween,
    required this.isNew,
    required this.onTap,
    this.compact = false,
    this.showPreviewButton = false,
    this.favoriteKind = FavoriteKind.coloring,
    this.showFavoriteButton = true,
    this.requiresAdUnlock = false,
    this.starLockCost,
  });

  final ColoringPage page;
  final bool isHalloween;
  final bool isNew;
  final bool compact;
  final bool showPreviewButton;
  final FavoriteKind favoriteKind;
  final bool showFavoriteButton;
  /// Motiv aus dem letzten Event — Badge bis zur Ad-Freischaltung.
  final bool requiresAdUnlock;
  /// Stern-Preis wenn noch nicht freigeschaltet.
  final int? starLockCost;
  final VoidCallback onTap;

  Future<void> _openPreview(BuildContext context) async {
    final choice = await PuzzlePreviewOverlay.show(context, page);
    if (choice != null && context.mounted) onTap();
  }

  /// Stern sitzt an der echten Bild-Ecke (Aspect-Box), nicht der Letterbox-Kachel.
  Widget _pictureStack({required BoxFit fit}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final badgeSize = (side * 0.38).clamp(42.0, 60.0);
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.95),
                child: ColoringPageImage(
                  page: page,
                  fit: fit,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (starLockCost != null)
              Positioned(
                // Leicht über den Innenrand in den Holzrahmen.
                left: -6,
                bottom: -6,
                child: _StarLockBadge(
                  cost: starLockCost!,
                  size: badgeSize,
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final aspect = page.aspectRatio <= 0 ? 0.78 : page.aspectRatio;
    final framed = GalleryFrame(
      style: isHalloween
          ? GalleryFrameStyle.halloween
          : GalleryFrameStyle.fantasy,
      showHalloweenBadge: false,
      child: compact
          ? _pictureStack(fit: BoxFit.cover)
          : Center(
              child: AspectRatio(
                aspectRatio: aspect,
                child: _pictureStack(fit: BoxFit.cover),
              ),
            ),
    );

    final starSize = compact ? 34.0 : 42.0;
    final inset = compact ? 8.0 : 12.0;
    final previewSize = compact ? 34.0 : 40.0;
    final t = AppStrings.of(context);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(onTap: onTap, child: framed),
        ),
        if (isNew)
          Positioned(
            left: inset,
            top: inset,
            child: const NewBadge(),
          ),
        if (starLockCost == null && requiresAdUnlock)
          Positioned(
            left: inset,
            bottom: inset,
            child: AdUnlockBadge(
              label: t.unlockWithAd,
              compact: compact,
            ),
          )
        else if (starLockCost == null && !showPreviewButton)
          Selector<ColoringProgressStore, bool>(
            selector: (_, store) => store.hasProgress(page.id),
            builder: (context, hasProgress, _) {
              if (!hasProgress) return const SizedBox.shrink();
              return Positioned(
                left: inset,
                bottom: inset,
                child: const ProgressBadge(label: 'Continue'),
              );
            },
          ),
        if (showFavoriteButton)
          Positioned(
            top: inset,
            right: inset,
            child: Selector<FavoritesStore, bool>(
              selector: (_, store) =>
                  store.isFavorite(page.id, kind: favoriteKind),
              builder: (context, isFavorite, _) {
                return FavoriteStarButton(
                  isFavorite: isFavorite,
                  onPressed: () => context.read<FavoritesStore>().toggle(
                        page.id,
                        kind: favoriteKind,
                      ),
                  size: starSize,
                );
              },
            ),
          ),
        if (showPreviewButton)
          Positioned(
            right: inset,
            bottom: inset,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => unawaited(_openPreview(context)),
                customBorder: const CircleBorder(),
                child: Ink(
                  width: previewSize,
                  height: previewSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.65),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.visibility_rounded,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: previewSize * 0.55,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Stern-Preis als Siegel an der Bild-Ecke, Zahl mittig auf dem Stern.
class _StarLockBadge extends StatelessWidget {
  const _StarLockBadge({required this.cost, required this.size});

  final int cost;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fontSize = cost >= 100 ? size * 0.26 : size * 0.30;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/images/sternicon.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          Text(
            '$cost',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF2A1A08),
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: const [
                Shadow(
                  color: Color(0xEEFFF4C8),
                  blurRadius: 4,
                ),
                Shadow(
                  color: Color(0xAAFFF4C8),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

