import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/coloring_pages_loader.dart';
import '../data/event_catalog.dart';
import '../data/event_tags.dart';
import '../data/puzzle_images_loader.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../providers/favorites_store.dart';
import '../providers/recent_content_store.dart';
import '../providers/sticker_collection_store.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/remote_pack_service.dart';
import '../utils/app_layout.dart';
import '../utils/app_page_route.dart';
import '../utils/asset_precache.dart';
import '../widgets/catalog_gallery_body.dart';
import '../widgets/silver_back_button.dart';
import '../widgets/sticker_album_overlay.dart';
import '../widgets/sticker_daily_gift_overlay.dart';
import '../widgets/welcome_portal_overlay.dart';
import 'coloring_preview_screen.dart';
import 'event_pack_gallery_screen.dart';
import 'favorites_screen.dart';
import 'print_templates_screen.dart';
import 'puzzle_screen.dart';
import 'settings_screen.dart';

/// Zentraler Einstieg: Tabs Home / Puzzle / Malen + Top-Aktionen.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';
  static const coloringLogo = 'assets/images/malen_favorit.png';
  static const puzzleLogo = 'assets/images/puzzle_favorit.png';

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin {
  static const _welcomeSeenKey = 'welcome_portal_seen_v1';

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  int _tabIndex = 0;
  bool _showWelcome = false;
  bool _showAlbum = false;
  bool _showDaily = false;
  bool _dailyChecked = false;
  int _heardGeneration = -1;

  Future<_HubCatalog>? _catalogFuture;
  final _homeScroll = ScrollController();
  final _puzzleGridScroll = ScrollController();
  final _puzzleRowScroll = ScrollController();
  final _colorGridScroll = ScrollController();
  final _colorRowScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(AudioService.instance.startAmbient());
    _reloadCatalog();
    _heardGeneration = RemotePackService.instance.generation;
    RemotePackService.instance.addListener(_onRemoteChanged);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowWelcome());
      unawaited(
        NotificationService.instance.scheduleGentleReminders(context),
      );
    });
  }

  void _onRemoteChanged() {
    final gen = RemotePackService.instance.generation;
    if (!mounted || gen == _heardGeneration) return;
    _heardGeneration = gen;
    setState(_reloadCatalog);
  }

  void _reloadCatalog() {
    _catalogFuture = _loadCatalog();
  }

  Future<_HubCatalog> _loadCatalog() async {
    final tags = await EventTags.load();
    final coloring = await loadColoringCatalog(shuffle: false);
    final puzzle = await loadPuzzleCatalog(shuffle: false);
    return _HubCatalog(tags: tags, coloring: coloring, puzzle: puzzle);
  }

  Future<void> _maybeShowWelcome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_welcomeSeenKey) == true) {
        await _maybeShowDailyGift();
        return;
      }
      if (!mounted) return;
      setState(() => _showWelcome = true);
    } catch (_) {
      await _maybeShowDailyGift();
    }
  }

  Future<void> _dismissWelcome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_welcomeSeenKey, true);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _showWelcome = false);
    await _maybeShowDailyGift();
  }

  Future<void> _maybeShowDailyGift() async {
    if (_dailyChecked || !mounted) return;
    _dailyChecked = true;
    var ready = false;
    for (var i = 0; i < 20; i++) {
      final store = context.read<StickerCollectionStore>();
      if (store.isReady) {
        ready = store.canClaimDaily;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    if (!ready || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _showDaily = true);
  }

  @override
  void dispose() {
    RemotePackService.instance.removeListener(_onRemoteChanged);
    _fadeController.dispose();
    _homeScroll.dispose();
    _puzzleGridScroll.dispose();
    _puzzleRowScroll.dispose();
    _colorGridScroll.dispose();
    _colorRowScroll.dispose();
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

  void _openAlbum() {
    AnalyticsService.instance.logScreen('sticker_album');
    setState(() => _showAlbum = true);
  }

  void _openFavorites() {
    _open(const FavoritesScreen(), world: 'favoriten');
  }

  void _openPrint() {
    _open(const PrintTemplatesScreen(), world: 'drucken');
  }

  void _openSettings() {
    AnalyticsService.instance.logOpenWorld('settings');
    AnalyticsService.instance.logScreen('settings');
    Navigator.of(context).push(
      AppPageRoute<void>(
        settings: const RouteSettings(name: 'settings'),
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  void _openColoring(ColoringPage page) {
    AnalyticsService.instance.logStartColoring(page.id);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => ColoringPreviewScreen(page: page),
      ),
    );
  }

  void _openPuzzle(ColoringPage page) {
    AnalyticsService.instance.logStartPuzzle(page.id);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PuzzleScreen(puzzle: page),
      ),
    );
  }

  void _selectTab(int i) {
    if (i == _tabIndex) return;
    setState(() => _tabIndex = i);
    AnalyticsService.instance.logScreen(
      switch (i) {
        0 => 'hub_home',
        1 => 'hub_puzzle',
        _ => 'hub_color',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

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
                  _HubTopBar(
                    tabIndex: _tabIndex,
                    onSelectTab: _selectTab,
                    onAlbum: _openAlbum,
                    onPrint: _openPrint,
                    onFavorites: _openFavorites,
                    onSettings: _openSettings,
                  ),
                  Expanded(
                    child: FutureBuilder<_HubCatalog>(
                      key: ValueKey('hub_catalog_$_heardGeneration'),
                      future: _catalogFuture,
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
                        final data = snapshot.data;
                        if (data == null) {
                          return const Center(
                            child: Text(
                              'No content found',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }

                        return IndexedStack(
                          index: _tabIndex,
                          children: [
                            _HomeTab(
                              catalog: data,
                              scrollController: _homeScroll,
                              onOpenColoring: _openColoring,
                              onOpenPuzzle: _openPuzzle,
                            ),
                            CatalogGalleryBody(
                              catalog: data.puzzle,
                              tags: data.tags,
                              kind: CatalogGalleryKind.puzzle,
                              categoryTitle: t.puzzle,
                              showEventHubs: false,
                              showCategoryTitle: false,
                              showDownloadButton: true,
                              onOpenPage: _openPuzzle,
                              gridScroll: _puzzleGridScroll,
                              rowScroll: _puzzleRowScroll,
                            ),
                            CatalogGalleryBody(
                              catalog: data.coloring,
                              tags: data.tags,
                              kind: CatalogGalleryKind.coloring,
                              categoryTitle: t.color,
                              showEventHubs: false,
                              showCategoryTitle: false,
                              onOpenPage: _openColoring,
                              gridScroll: _colorGridScroll,
                              rowScroll: _colorRowScroll,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showWelcome)
            WelcomePortalOverlay(
              onFinished: () => unawaited(_dismissWelcome()),
            ),
          if (_showDaily)
            Builder(
              builder: (context) {
                final strings = AppStrings.of(context);
                return StickerDailyGiftOverlay(
                  isDaily: true,
                  title: strings.dailySurprise,
                  subtitle: strings.pickBoxToday,
                  revealTitle: strings.dailyReward,
                  onClosed: () {
                    if (mounted) setState(() => _showDaily = false);
                  },
                );
              },
            ),
          if (_showAlbum)
            StickerAlbumOverlay(
              onClose: () {
                if (mounted) setState(() => _showAlbum = false);
              },
            ),
        ],
      ),
    );
  }
}

class _HubCatalog {
  const _HubCatalog({
    required this.tags,
    required this.coloring,
    required this.puzzle,
  });

  final EventTags tags;
  final GalleryCatalog coloring;
  final GalleryCatalog puzzle;
}

/// Oben: Album + Streak · Tabs (nur Icons) · Druck · Stern · Settings.
class _HubTopBar extends StatelessWidget {
  const _HubTopBar({
    required this.tabIndex,
    required this.onSelectTab,
    required this.onAlbum,
    required this.onPrint,
    required this.onFavorites,
    required this.onSettings,
  });

  final int tabIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onAlbum;
  final VoidCallback onPrint;
  final VoidCallback onFavorites;
  final VoidCallback onSettings;

  Widget _tabs({
    required AppStrings t,
    required bool tablet,
    required bool portrait,
  }) {
    final tabGap = portrait ? (tablet ? 22.0 : 18.0) : (tablet ? 18.0 : 14.0);
    final homeSize = portrait
        ? (tablet ? 46.0 : 40.0)
        : (tablet ? 48.0 : 42.0);
    final logoSize = portrait
        ? (tablet ? 54.0 : 48.0)
        : (tablet ? 56.0 : 50.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopTabIcon(
          selected: tabIndex == 0,
          semanticLabel: t.home,
          onTap: () => onSelectTab(0),
          child: Icon(
            Icons.home_rounded,
            size: homeSize,
            color: tabIndex == 0
                ? const Color(0xFFFFE7A0)
                : const Color(0xFFD0D8E8),
            shadows: [
              Shadow(
                color: tabIndex == 0
                    ? const Color(0xAAFFE7A0)
                    : const Color(0xAA000000),
                blurRadius: tabIndex == 0 ? 14 : 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        SizedBox(width: tabGap),
        _TopTabIcon(
          selected: tabIndex == 1,
          semanticLabel: t.puzzle,
          onTap: () => onSelectTab(1),
          child: _TabLogo(
            asset: HubScreen.puzzleLogo,
            selected: tabIndex == 1,
            size: logoSize,
          ),
        ),
        SizedBox(width: tabGap),
        _TopTabIcon(
          selected: tabIndex == 2,
          semanticLabel: t.color,
          onTap: () => onSelectTab(2),
          child: _TabLogo(
            asset: HubScreen.coloringLogo,
            selected: tabIndex == 2,
            size: logoSize,
          ),
        ),
      ],
    );
  }

  Widget _actions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlainIconButton(
          semanticLabel: 'Print',
          icon: Icons.print_rounded,
          size: 34,
          onPressed: onPrint,
        ),
        const SizedBox(width: 10),
        _PlainIconButton(
          semanticLabel: 'Favorites',
          icon: Icons.star_rounded,
          size: 36,
          onPressed: onFavorites,
        ),
        const SizedBox(width: 8),
        SilverBackButton(
          icon: Icons.settings_rounded,
          size: 44,
          iconSize: 22,
          onPressed: onSettings,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final layout = AppLayout.of(context);
    final tablet = layout.isTablet;
    final portrait = layout.isPortrait;

    // Portrait: Aktionen oben, Tabs darunter — sonst wird alles gequetscht.
    if (portrait) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _StickerBookButton(onPressed: onAlbum),
                const Spacer(),
                _actions(),
              ],
            ),
            const SizedBox(height: 4),
            _tabs(t: t, tablet: tablet, portrait: true),
          ],
        ),
      );
    }

    // Tabs echt mittig: Seiten-Icons in einer Row, Tabs als Overlay zentriert.
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              _StickerBookButton(onPressed: onAlbum),
              const Spacer(),
              _actions(),
            ],
          ),
          _tabs(t: t, tablet: tablet, portrait: false),
        ],
      ),
    );
  }
}

class _TopTabIcon extends StatelessWidget {
  const _TopTabIcon({
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFE7A0).withValues(alpha: 0.7)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TabLogo extends StatelessWidget {
  const _TabLogo({
    required this.asset,
    required this.selected,
    this.size = 50,
  });

  final String asset;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.08 : 0.94,
      duration: const Duration(milliseconds: 160),
      child: Opacity(
        opacity: selected ? 1 : 0.78,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

/// Home: Zuletzt → Neu → Favoriten → Letztes Event → Puzzle → Malen.
class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.catalog,
    required this.scrollController,
    required this.onOpenColoring,
    required this.onOpenPuzzle,
  });

  final _HubCatalog catalog;
  final ScrollController scrollController;
  final ValueChanged<ColoringPage> onOpenColoring;
  final ValueChanged<ColoringPage> onOpenPuzzle;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _precacheDone = false;

  List<ColoringPage> _flatten(GalleryCatalog catalog) {
    final byId = <String, ColoringPage>{};
    for (final event in catalog.activeEvents) {
      for (final page in event.pages) {
        byId[page.id] = page;
      }
    }
    for (final page in catalog.standard.pages) {
      byId[page.id] = page;
    }
    for (final event in catalog.pastEvents) {
      for (final page in event.pages) {
        byId.putIfAbsent(page.id, () => page);
      }
    }
    return byId.values.toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precacheDone) return;
    _precacheDone = true;
    final tags = widget.catalog.tags;
    final coloring = tags.sortNewestFirst(
      _flatten(widget.catalog.coloring),
      coloring: true,
    );
    final puzzles = tags.sortNewestFirst(
      _flatten(widget.catalog.puzzle),
      coloring: false,
    );
    final paths = <String>[
      ...coloring.take(12).map((p) => p.assetPath),
      ...puzzles.take(12).map((p) => p.assetPath),
    ];
    final cacheW = thumbCacheWidth(
      context,
      MediaQuery.sizeOf(context).shortestSide * 0.42,
    );
    unawaited(precacheAssetImages(context, paths, cacheWidth: cacheW));
  }

  List<ColoringPage> _pagesForIds(
    List<ColoringPage> all,
    Iterable<String> ids,
  ) {
    final byId = {for (final p in all) p.id: p};
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final tags = widget.catalog.tags;
    final favorites = context.watch<FavoritesStore>();
    final recent = context.watch<RecentContentStore>();
    final allColoring = tags.sortNewestFirst(
      _flatten(widget.catalog.coloring),
      coloring: true,
    );
    final allPuzzles = tags.sortNewestFirst(
      _flatten(widget.catalog.puzzle),
      coloring: false,
    );
    final coloringById = {for (final p in allColoring) p.id: p};
    final puzzleById = {for (final p in allPuzzles) p.id: p};
    final recentItems = <({ColoringPage page, FavoriteKind kind})>[
      for (final e in recent.entries())
        if (e.kind == FavoriteKind.coloring && coloringById[e.id] != null)
          (page: coloringById[e.id]!, kind: FavoriteKind.coloring)
        else if (e.kind == FavoriteKind.puzzle && puzzleById[e.id] != null)
          (page: puzzleById[e.id]!, kind: FavoriteKind.puzzle),
    ];

    final favColoring = _pagesForIds(
      allColoring,
      favorites.coloringIds(),
    );
    final favPuzzles = _pagesForIds(
      allPuzzles,
      favorites.puzzleIds(),
    );

    final lastEvent = tags.lastPastEvent();
    final lastColoring = lastEvent == null
        ? const <ColoringPage>[]
        : _pagesForIds(allColoring, lastEvent.coloringIds);
    final lastPuzzles = lastEvent == null
        ? const <ColoringPage>[]
        : _pagesForIds(allPuzzles, lastEvent.puzzleIds);
    final lastIds = {
      for (final p in lastColoring) p.id,
      for (final p in lastPuzzles) p.id,
    };

    final newColoring = allColoring
        .where((p) => tags.isNewColoring(p.id) && !lastIds.contains(p.id))
        .toList();
    final newPuzzles = allPuzzles
        .where((p) => tags.isNewPuzzle(p.id) && !lastIds.contains(p.id))
        .toList();
    final highlightIds = {
      ...lastIds,
      for (final p in newColoring) p.id,
      for (final p in newPuzzles) p.id,
    };

    final regularPuzzles =
        allPuzzles.where((p) => !highlightIds.contains(p.id)).toList();
    final regularColoring =
        allColoring.where((p) => !highlightIds.contains(p.id)).toList();
    final halloweenColor = tags.halloweenColoring;
    final halloweenPuzzle = tags.halloweenPuzzle;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _SectionHeader(title: t.recentlyUsed),
        if (recentItems.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 16, 12),
            child: Text(
              t.recentlyUsedEmpty,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          _HomeRecentRow(
            items: recentItems,
            isNew: (id, kind) => kind == FavoriteKind.coloring
                ? tags.isNewColoring(id)
                : tags.isNewPuzzle(id),
            isHalloween: (id, kind) => kind == FavoriteKind.coloring
                ? halloweenColor.contains(id)
                : halloweenPuzzle.contains(id),
            onOpenColoring: widget.onOpenColoring,
            onOpenPuzzle: widget.onOpenPuzzle,
          ),
        const SizedBox(height: 8),
        if (newPuzzles.isNotEmpty || newColoring.isNotEmpty) ...[
          _SectionHeader(title: t.newItems),
          if (newPuzzles.isNotEmpty)
            _HomeRow(
              label: t.newPuzzle,
              pages: newPuzzles,
              isNew: (_) => true,
              isHalloween: (id) => halloweenPuzzle.contains(id),
              favoriteKind: FavoriteKind.puzzle,
              showDownloadButton: true,
              onOpen: widget.onOpenPuzzle,
            ),
          if (newColoring.isNotEmpty)
            _HomeRow(
              label: t.newColor,
              pages: newColoring,
              isNew: (_) => true,
              isHalloween: (id) => halloweenColor.contains(id),
              favoriteKind: FavoriteKind.coloring,
              onOpen: widget.onOpenColoring,
            ),
          const SizedBox(height: 8),
        ],
        if (favPuzzles.isNotEmpty || favColoring.isNotEmpty) ...[
          _SectionHeader(title: t.favorites),
          if (favPuzzles.isNotEmpty)
            _HomeRow(
              label: t.puzzle,
              pages: favPuzzles,
              isNew: (id) => tags.isNewPuzzle(id),
              isHalloween: (id) => halloweenPuzzle.contains(id),
              favoriteKind: FavoriteKind.puzzle,
              showDownloadButton: true,
              onOpen: widget.onOpenPuzzle,
            ),
          if (favColoring.isNotEmpty)
            _HomeRow(
              label: t.color,
              pages: favColoring,
              isNew: (id) => tags.isNewColoring(id),
              isHalloween: (id) => halloweenColor.contains(id),
              favoriteKind: FavoriteKind.coloring,
              onOpen: widget.onOpenColoring,
            ),
          const SizedBox(height: 8),
        ],
        if (lastColoring.isNotEmpty || lastPuzzles.isNotEmpty) ...[
          _SectionHeader(
            title: lastEvent?.title.isNotEmpty == true
                ? '${t.lastEvent}: ${lastEvent!.title}'
                : t.lastEvent,
          ),
          if (lastPuzzles.isNotEmpty)
            _HomeRow(
              label: t.puzzle,
              pages: lastPuzzles,
              isNew: (_) => false,
              isHalloween: (id) => halloweenPuzzle.contains(id),
              favoriteKind: FavoriteKind.puzzle,
              showDownloadButton: true,
              onOpen: widget.onOpenPuzzle,
            ),
          if (lastColoring.isNotEmpty)
            _HomeRow(
              label: t.color,
              pages: lastColoring,
              isNew: (_) => false,
              isHalloween: (id) => halloweenColor.contains(id),
              favoriteKind: FavoriteKind.coloring,
              onOpen: widget.onOpenColoring,
            ),
          const SizedBox(height: 8),
        ],
        if (regularPuzzles.isNotEmpty) ...[
          _SectionHeader(title: t.puzzle),
          _HomeRow(
            pages: regularPuzzles,
            isNew: (id) => tags.isNewPuzzle(id),
            isHalloween: (id) => halloweenPuzzle.contains(id),
            favoriteKind: FavoriteKind.puzzle,
            showDownloadButton: true,
            onOpen: widget.onOpenPuzzle,
          ),
        ],
        if (regularColoring.isNotEmpty) ...[
          _SectionHeader(title: t.color),
          _HomeRow(
            pages: regularColoring,
            isNew: (id) => tags.isNewColoring(id),
            isHalloween: (id) => halloweenColor.contains(id),
            favoriteKind: FavoriteKind.coloring,
            onOpen: widget.onOpenColoring,
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isTablet = AppLayout.of(context).isTablet;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          color: const Color(0xFFFFE7A0),
          fontSize: isTablet ? 24 : 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          shadows: const [
            Shadow(
              color: Color(0xAA000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeRecentRow extends StatelessWidget {
  const _HomeRecentRow({
    required this.items,
    required this.isNew,
    required this.isHalloween,
    required this.onOpenColoring,
    required this.onOpenPuzzle,
  });

  final List<({ColoringPage page, FavoriteKind kind})> items;
  final bool Function(String id, FavoriteKind kind) isNew;
  final bool Function(String id, FavoriteKind kind) isHalloween;
  final ValueChanged<ColoringPage> onOpenColoring;
  final ValueChanged<ColoringPage> onOpenPuzzle;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final rowHeight = layout.isLandscape
        ? (size.height * 0.34).clamp(150.0, 240.0)
        : (size.height * 0.20).clamp(128.0, layout.isTablet ? 220.0 : 176.0);

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(width: size.width * 0.028),
        itemBuilder: (context, index) {
          final item = items[index];
          final page = item.page;
          final kind = item.kind;
          final ratio = page.aspectRatio <= 0 ? 0.78 : page.aspectRatio;
          final tileWidth = (rowHeight * ratio).clamp(
            rowHeight * 0.55,
            rowHeight * 1.55,
          );
          return SizedBox(
            width: tileWidth,
            height: rowHeight,
            child: GalleryPageTile(
              page: page,
              isHalloween: isHalloween(page.id, kind),
              isNew: isNew(page.id, kind),
              showFavoriteButton: true,
              showDownloadButton: kind == FavoriteKind.puzzle,
              favoriteKind: kind,
              onTap: () => kind == FavoriteKind.puzzle
                  ? onOpenPuzzle(page)
                  : onOpenColoring(page),
            ),
          );
        },
      ),
    );
  }
}

class _HomeRow extends StatelessWidget {
  const _HomeRow({
    required this.pages,
    required this.isNew,
    required this.isHalloween,
    required this.favoriteKind,
    required this.onOpen,
    this.label,
    this.showDownloadButton = false,
  });

  final List<ColoringPage> pages;
  final String? label;
  final bool Function(String id) isNew;
  final bool Function(String id) isHalloween;
  final FavoriteKind favoriteKind;
  final ValueChanged<ColoringPage> onOpen;
  final bool showDownloadButton;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    // Portrait: etwas höhere Reihen (mehr Fläche), Landscape: flacher.
    final rowHeight = layout.isLandscape
        ? (size.height * 0.34).clamp(150.0, 240.0)
        : (size.height * 0.20).clamp(128.0, layout.isTablet ? 220.0 : 176.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 16, 4),
            child: Text(
              label!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
            itemCount: pages.length,
            separatorBuilder: (_, _) => SizedBox(width: size.width * 0.028),
            itemBuilder: (context, index) {
              final page = pages[index];
              final ratio = page.aspectRatio <= 0 ? 0.78 : page.aspectRatio;
              final tileWidth = (rowHeight * ratio).clamp(
                rowHeight * 0.55,
                rowHeight * 1.55,
              );
              return SizedBox(
                width: tileWidth,
                height: rowHeight,
                child: GalleryPageTile(
                  page: page,
                  isHalloween: isHalloween(page.id),
                  isNew: isNew(page.id),
                  showFavoriteButton: true,
                  showDownloadButton: showDownloadButton,
                  favoriteKind: favoriteKind,
                  onTap: () => onOpen(page),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StickerBookButton extends StatelessWidget {
  const _StickerBookButton({required this.onPressed});

  final VoidCallback onPressed;

  static const asset = 'assets/images/buch_icon.png';

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.sizeOf(context).shortestSide;
    final size = side >= 600 ? 58.0 : 50.0;
    return Semantics(
      button: true,
      label: 'Sticker album',
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class _PlainIconButton extends StatelessWidget {
  const _PlainIconButton({
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    this.size = 28,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: size,
              color: const Color(0xFFFFF6E8),
              shadows: const [
                Shadow(
                  color: Color(0xAA000000),
                  blurRadius: 8,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
