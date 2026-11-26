import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/coloring_pages_loader.dart';
import '../data/event_catalog.dart';
import '../data/event_tags.dart';
import '../data/puzzle_images_loader.dart';
import '../data/sticker_catalog.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../models/pixel_puzzle.dart';
import '../painting/colored_png_probe.dart';
import '../providers/coloring_progress_store.dart';
import '../providers/favorites_store.dart';
import '../providers/pixel_progress_store.dart';
import '../providers/pixel_ready_store.dart';
import '../providers/recent_content_store.dart';
import '../providers/star_wallet_store.dart';
import '../providers/sticker_collection_store.dart';
import '../services/ads_service.dart';
import '../services/advent_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/event_content_gate.dart';
import '../services/notification_service.dart';
import '../services/remote_pack_service.dart';
import '../services/daily_quest_service.dart';
import '../services/star_content_gate.dart';
import '../utils/app_layout.dart';
import '../utils/app_orientations.dart';
import '../utils/app_page_route.dart';
import '../utils/app_route_observer.dart';
import '../utils/asset_precache.dart';
import '../widgets/catalog_gallery_body.dart';
import '../widgets/daily_quest_overlay.dart';
import '../widgets/daily_quest_pill.dart';
import '../widgets/daily_quest_reward.dart';
import '../widgets/event_hub_portal.dart';
import '../widgets/star_balance_pill.dart';
import '../widgets/star_earn_overlay.dart';
import '../widgets/sticker_album_overlay.dart';
import '../widgets/welcome_portal_overlay.dart';
import '../widgets/winter_atmosphere_overlay.dart';
import 'advent_calendar_screen.dart';
import 'coloring_preview_screen.dart';
import 'event_pack_gallery_screen.dart';
import 'event_world_hub_screen.dart';
import 'favorites_screen.dart';
import 'pixel_paint_screen.dart';
import 'print_templates_screen.dart';
import 'puzzle_screen.dart';
import 'settings_screen.dart';

/// Zentraler Einstieg: Bottom-Nav + Topbar (Sterne / Daily / Utilities).
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';
  static const homeLogo = 'assets/images/homeicon.house.png';
  static const settingsLogo = 'assets/images/gold-zahnrad-setting.png';
  static const printLogo = 'assets/images/magischer.drucker.png';
  static const coloringLogo = 'assets/images/malen_favorit.png';
  static const puzzleLogo = 'assets/images/puzzle_favorit.png';
  static const eventsLogo = 'assets/images/events-button.png';
  static const pixelLogo = 'assets/images/pixelart_hub.png';
  /// Neben dem Stickeralbum — Datei ersetzen, wenn neues Asset fertig ist.
  static const adventButtonAsset = 'assets/images/advent_menu_button.png';


  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  static const _welcomeSeenKey = 'welcome_portal_seen_v1';

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  int _tabIndex = 0;
  bool _showWelcome = false;
  bool _showAlbum = false;
  bool _flushingCelebrations = false;
  StickerAlbumKind _albumKind = StickerAlbumKind.classic;
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
    unawaited(AppOrientations.lockHubPortrait());
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
    // Stickers liegen nicht im Hub-Katalog — nach CDN-Sync extra neu mergen.
    unawaited(context.read<StickerCollectionStore>().reloadCatalog());
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
      if (prefs.getBool(_welcomeSeenKey) == true) return;
      if (!mounted) return;
      setState(() => _showWelcome = true);
    } catch (_) {}
  }

  Future<void> _dismissWelcome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_welcomeSeenKey, true);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _showWelcome = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    RemotePackService.instance.removeListener(_onRemoteChanged);
    _fadeController.dispose();
    _homeScroll.dispose();
    _puzzleGridScroll.dispose();
    _puzzleRowScroll.dispose();
    _colorGridScroll.dispose();
    _colorRowScroll.dispose();
    unawaited(AppOrientations.lockHubPortrait());
    super.dispose();
  }

  @override
  void didPopNext() {
    // Zurück aus Play → Menü wieder Hochkant.
    unawaited(AppOrientations.lockHubPortrait());
    // Zurück aus Ausmalen/Puzzle/… → Daily-Liste + Sterne-Show.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_flushHubCelebrations());
    });
  }

  /// Daily-Belohnung + verdiente Sterne erst hier im Hub.
  Future<void> _flushHubCelebrations() async {
    if (!mounted || _flushingCelebrations) return;
    _flushingCelebrations = true;
    try {
      final quest = context.read<DailyQuestService>();
      final wallet = context.read<StarWalletStore>();
      final pending = await quest.takePendingHubCelebration();
      if (!mounted) return;

      if (pending != null) {
        if (pending.openList) {
          await DailyQuestOverlay.show(context);
          if (!mounted) return;
        }
        if (pending.stickers > 0 || pending.stars > 0) {
          await DailyQuestReward.maybeShow(
            context,
            stickerCount: pending.stickers,
            bonusStars: pending.stars,
          );
          if (!mounted) return;
        }
      }

      final earned = wallet.takePendingHubStars();
      if (earned > 0 && mounted) {
        await StarEarnOverlay.show(
          context,
          amount: earned,
          newTotal: wallet.balance,
        );
      }
    } finally {
      _flushingCelebrations = false;
    }
  }

  Future<void> _open(Widget screen, {required String world}) async {
    AnalyticsService.instance.logOpenWorld(world);
    AnalyticsService.instance.logScreen(world);
    await Navigator.of(context).push(
      AppPageRoute<void>(
        settings: RouteSettings(name: world),
        builder: (_) => screen,
      ),
    );
    if (mounted) await _flushHubCelebrations();
  }

  void _openAlbumKind(StickerAlbumKind kind) {
    AnalyticsService.instance.logScreen('sticker_album');
    setState(() {
      _albumKind = kind;
      _showAlbum = true;
    });
  }

  void _openAdvent() {
    _open(const AdventCalendarScreen(), world: 'advent');
  }

  void _openPrint() {
    _open(const PrintTemplatesScreen(), world: 'drucken');
  }

  Future<void> _openSettings() async {
    AnalyticsService.instance.logOpenWorld('settings');
    AnalyticsService.instance.logScreen('settings');
    await Navigator.of(context).push(
      AppPageRoute<void>(
        settings: const RouteSettings(name: 'settings'),
        builder: (_) => const SettingsScreen(),
      ),
    );
    if (mounted) await _flushHubCelebrations();
  }

  Future<void> _openColoring(ColoringPage page) async {
    final ok = await StarContentGate.ensureUnlocked(
      context,
      id: page.id,
      kind: FavoriteKind.coloring,
    );
    if (!ok || !mounted) return;
    AnalyticsService.instance.logStartColoring(page.id);
    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => ColoringPreviewScreen(page: page),
      ),
    );
    if (mounted) await _flushHubCelebrations();
  }

  Future<void> _openPuzzle(ColoringPage page) async {
    final ok = await StarContentGate.ensureUnlocked(
      context,
      id: page.id,
      kind: FavoriteKind.puzzle,
    );
    if (!ok || !mounted) return;
    AnalyticsService.instance.logStartPuzzle(page.id);
    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PuzzleScreen(puzzle: page),
      ),
    );
    if (mounted) await _flushHubCelebrations();
  }

  void _selectTab(int i) {
    if (i == _tabIndex) return;
    setState(() => _tabIndex = i);
    AnalyticsService.instance.logScreen(
      switch (i) {
        0 => 'hub_home',
        1 => 'hub_puzzle',
        2 => 'hub_color',
        3 => 'hub_events',
        _ => 'hub_favorites',
      },
    );
  }

  Future<void> _openPixel(ColoringPage page) async {
    HapticFeedback.selectionClick();
    final readyStore = context.read<PixelReadyStore>();
    final store = context.read<PixelProgressStore>();
    final coloringProgress = context.read<ColoringProgressStore>();
    if (!readyStore.isPaintUnlocked(page.id)) {
      await AdsService.showEventContentUnlockInterstitial();
      if (!mounted) return;
      await readyStore.unlockPaint(page.id);
    }
    if (!mounted) return;
    final existing = await store.loadSnapshot(page.id);
    final sourceBytes = await coloringProgress.loadProgressBytes(page.id);
    if (!mounted) return;
    if (sourceBytes == null ||
        !await ColoredPngProbe.hasFillColors(sourceBytes)) {
      if (!mounted) return;
      final wallet = context.read<StarWalletStore>();
      await readyStore.revokeReady(page.id);
      await store.clearProgress(page.id);
      // Sonst holt syncFromCompletedColoring die ID über stale Rating ≥ 3 zurück.
      await wallet.clearColoringRating(page.id);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).pixelNeedsColoring)),
      );
      return;
    }
    PixelProgressSnapshot? resume;
    if (existing != null && !existing.completed && existing.filledCount > 0) {
      resume = existing;
    } else if (existing != null) {
      await store.clearProgress(page.id);
    }
    if (!mounted) return;
    await _open(
      PixelPaintScreen(
        page: page,
        difficulty: PixelDifficulty.standard,
        sourceBytes: sourceBytes,
        resumeSnapshot: resume,
      ),
      world: 'pixel',
    );
  }

  Future<void> _openEventWorld({
    required ContentEvent event,
    required GallerySection coloring,
    required GallerySection puzzle,
    required EventTags tags,
  }) async {
    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => EventWorldHubScreen(
          title: event.title,
          coloringSection: coloring,
          puzzleSection: puzzle,
          isHalloween: event.id.toLowerCase().contains('halloween'),
          halloweenIds: {
            ...tags.halloweenColoring,
            ...tags.halloweenPuzzle,
          },
          tags: tags,
        ),
      ),
    );
    if (mounted) await _flushHubCelebrations();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    final winterUi = AdventService.isWinterHubUi();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            winterUi
                ? 'assets/images/winterhintergrund.png'
                : HubScreen.backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          if (winterUi) const WinterAtmosphereOverlay(),
          FadeTransition(
            opacity: _fadeAnimation,
            // Content vollflächig; Bottom-Nav als transparentes Overlay,
            // damit Kacheln darunter durchscrollen.
            child: Stack(
              fit: StackFit.expand,
              children: [
                SafeArea(
                  bottom: false,
                  maintainBottomViewPadding: true,
                  child: Column(
                    children: [
                      _HubTopBar(
                        onOpenClassicAlbum: () =>
                            _openAlbumKind(StickerAlbumKind.classic),
                        onOpenWinterAlbum: winterUi
                            ? () => _openAlbumKind(StickerAlbumKind.winter)
                            : null,
                        onAdvent: winterUi ? _openAdvent : null,
                        onAdventLongPress: null,
                        onPrint: _openPrint,
                        onSettings: _openSettings,
                      ),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final clearance =
                                _HubBottomNav.clearance(context);
                            final mq = MediaQuery.of(context);
                            return MediaQuery(
                              data: mq.copyWith(
                                padding: mq.padding.copyWith(
                                  bottom: clearance,
                                ),
                              ),
                              child: FutureBuilder<_HubCatalog>(
                                key: ValueKey(
                                  'hub_catalog_$_heardGeneration',
                                ),
                                future: _catalogFuture,
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

                                  return switch (_tabIndex) {
                                    1 => CatalogGalleryBody(
                                        catalog: data.puzzle,
                                        tags: data.tags,
                                        kind: CatalogGalleryKind.puzzle,
                                        categoryTitle: t.puzzle,
                                        showEventHubs: false,
                                        showCategoryTitle: false,
                                        includePastEventPages: false,
                                        showPreviewButton: true,
                                        onOpenPage: _openPuzzle,
                                        gridScroll: _puzzleGridScroll,
                                        rowScroll: _puzzleRowScroll,
                                      ),
                                    2 => CatalogGalleryBody(
                                        catalog: data.coloring,
                                        tags: data.tags,
                                        kind: CatalogGalleryKind.coloring,
                                        categoryTitle: t.color,
                                        showEventHubs: false,
                                        showCategoryTitle: false,
                                        includePastEventPages: false,
                                        onOpenPage: _openColoring,
                                        gridScroll: _colorGridScroll,
                                        rowScroll: _colorRowScroll,
                                      ),
                                    3 => _EventsTab(
                                        catalog: data,
                                        onOpenEvent:
                                            (event, coloring, puzzle) {
                                          _openEventWorld(
                                            event: event,
                                            coloring: coloring,
                                            puzzle: puzzle,
                                            tags: data.tags,
                                          );
                                        },
                                      ),
                                    4 =>
                                      const FavoritesScreen(embedded: true),
                                    _ => _HomeTab(
                                        catalog: data,
                                        scrollController: _homeScroll,
                                        onOpenColoring: _openColoring,
                                        onOpenPuzzle: _openPuzzle,
                                        onOpenPixel: _openPixel,
                                      ),
                                  };
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _HubBottomNav(
                    tabIndex: _tabIndex,
                    onSelectTab: _selectTab,
                  ),
                ),
              ],
            ),
          ),
          if (_showWelcome)
            WelcomePortalOverlay(
              onFinished: () => unawaited(_dismissWelcome()),
            ),
          if (_showAlbum)
            StickerAlbumOverlay(
              album: _albumKind,
              onClose: () {
                if (!mounted) return;
                setState(() => _showAlbum = false);
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

class _HubTopBar extends StatefulWidget {
  const _HubTopBar({
    required this.onOpenClassicAlbum,
    required this.onPrint,
    required this.onSettings,
    this.onOpenWinterAlbum,
    this.onAdvent,
    this.onAdventLongPress,
  });

  final VoidCallback onOpenClassicAlbum;
  final VoidCallback? onOpenWinterAlbum;
  final VoidCallback? onAdvent;
  final VoidCallback? onAdventLongPress;
  final VoidCallback onPrint;
  final VoidCallback onSettings;

  @override
  State<_HubTopBar> createState() => _HubTopBarState();
}

class _HubTopBarState extends State<_HubTopBar> {
  bool _utilsOpen = false;
  bool _albumOpen = false;

  void _toggleUtils() => setState(() {
        _utilsOpen = !_utilsOpen;
        if (_utilsOpen) _albumOpen = false;
      });

  void _toggleAlbum() => setState(() {
        _albumOpen = !_albumOpen;
        if (_albumOpen) _utilsOpen = false;
      });

  @override
  Widget build(BuildContext context) {
    final winter = widget.onAdvent != null;
    final winterAlbums = widget.onOpenWinterAlbum != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tight = width < 520 || (winter && width < 640);
        final micro = width < 400 || (winter && width < 480);
        final utilSize = micro ? 40.0 : (tight ? 44.0 : 48.0);
        final albumSize = micro ? 48.0 : (tight ? 56.0 : 64.0);
        final gap = micro ? 4.0 : (tight ? 8.0 : 10.0);
        final albumAdventGap = micro ? 14.0 : (tight ? 18.0 : 22.0);
        return Padding(
          padding: EdgeInsets.fromLTRB(micro ? 4 : 8, 4, micro ? 4 : 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AlbumMenuPill(
                          open: _albumOpen,
                          winterChoice: winterAlbums,
                          iconSize: albumSize,
                          onToggle: winterAlbums
                              ? _toggleAlbum
                              : () {
                                  setState(() => _albumOpen = false);
                                  widget.onOpenClassicAlbum();
                                },
                          onClassic: () {
                            setState(() => _albumOpen = false);
                            widget.onOpenClassicAlbum();
                          },
                          onWinter: () {
                            setState(() => _albumOpen = false);
                            widget.onOpenWinterAlbum?.call();
                          },
                        ),
                        if (winter) ...[
                          SizedBox(width: albumAdventGap),
                          _AdventMenuButton(
                            onPressed: widget.onAdvent!,
                            onLongPress: widget.onAdventLongPress,
                            compact: tight,
                            micro: micro,
                          ),
                        ],
                        SizedBox(width: gap),
                        DailyQuestPill(compact: true),
                      ],
                    ),
                  ),
                ),
              ),
              StarBalancePill(compact: true),
              SizedBox(width: gap),
              _UtilitiesMenuPill(
                open: _utilsOpen,
                onToggle: _toggleUtils,
                iconSize: utilSize,
                onPrint: () {
                  setState(() => _utilsOpen = false);
                  widget.onPrint();
                },
                onSettings: () {
                  setState(() => _utilsOpen = false);
                  widget.onSettings();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Stickeralbum-Pille: Winter als aktuelles Face; Erweiterung zeigt Klassik.
class _AlbumMenuPill extends StatelessWidget {
  const _AlbumMenuPill({
    required this.open,
    required this.winterChoice,
    required this.iconSize,
    required this.onToggle,
    required this.onClassic,
    required this.onWinter,
  });

  final bool open;
  final bool winterChoice;
  final double iconSize;
  final VoidCallback onToggle;
  final VoidCallback onClassic;
  final VoidCallback onWinter;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final choiceSize = iconSize * 0.92;

    if (!winterChoice) {
      return _StickerBookButton(
        onPressed: onToggle,
        winter: false,
        size: iconSize,
      );
    }

    // Kein Pill-Chrome: Klassik schiebt sich unter dem Winter-Face raus.
    const duration = Duration(milliseconds: 280);
    const curve = Curves.easeOutCubic;
    final slideLeft = open ? iconSize * 0.88 : (iconSize - choiceSize) / 2;
    final totalWidth = open ? iconSize + choiceSize * 0.95 : iconSize;

    return AnimatedContainer(
      duration: duration,
      curve: curve,
      width: totalWidth,
      height: iconSize,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          AnimatedPositioned(
            duration: duration,
            curve: curve,
            left: slideLeft,
            top: (iconSize - choiceSize) / 2,
            width: choiceSize,
            height: choiceSize,
            child: IgnorePointer(
              ignoring: !open,
              child: Semantics(
                button: true,
                label: t.classicStickerAlbum,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClassic,
                  child: Image.asset(
                    _StickerBookButton.classicAsset,
                    width: choiceSize,
                    height: choiceSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: iconSize,
            height: iconSize,
            child: Semantics(
              button: true,
              label: open ? t.winterStickerAlbum : 'Sticker albums',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: open ? onWinter : onToggle,
                child: Image.asset(
                  _StickerBookButton.winterAsset,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hamburger rechts; öffnet Print + Settings in einer Pille nach links.
class _UtilitiesMenuPill extends StatelessWidget {
  const _UtilitiesMenuPill({
    required this.open,
    required this.onToggle,
    required this.onPrint,
    required this.onSettings,
    required this.iconSize,
  });

  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onPrint;
  final VoidCallback onSettings;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StarBalancePill.fill.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: StarBalancePill.border.withValues(alpha: 0.95),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: StarBalancePill.glow.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRect(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerRight,
                  widthFactor: open ? 1 : 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PlainIconButton(
                        semanticLabel: 'Print',
                        asset: HubScreen.printLogo,
                        size: iconSize,
                        dense: true,
                        onPressed: onPrint,
                      ),
                      _PlainIconButton(
                        semanticLabel: 'Settings',
                        asset: HubScreen.settingsLogo,
                        size: iconSize,
                        dense: true,
                        onPressed: onSettings,
                      ),
                    ],
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: open ? 'Close menu' : 'Open menu',
                child: InkWell(
                  onTap: onToggle,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        open ? Icons.close_rounded : Icons.menu_rounded,
                        key: ValueKey(open),
                        size: iconSize * 0.72,
                        color: StarBalancePill.ink,
                      ),
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

class _HubBottomNav extends StatelessWidget {
  const _HubBottomNav({
    required this.tabIndex,
    required this.onSelectTab,
  });

  final int tabIndex;
  final ValueChanged<int> onSelectTab;

  /// Platz unter Scroll-Inhalten, damit Letzte Kacheln über die Icons kommen.
  static double clearance(BuildContext context) {
    final tablet = AppLayout.of(context).isTablet;
    final logo = tablet ? 68.0 : 60.0;
    // Icon + Pill-Padding + Float-Margin + Home-Indicator.
    return logo + 8 + 8 + MediaQuery.viewPaddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final layout = AppLayout.of(context);
    final logoSize = layout.isTablet ? 68.0 : 60.0;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    Widget item({
      required int index,
      required String semanticLabel,
      required String asset,
    }) {
      final selected = tabIndex == index;
      return Expanded(
        child: Semantics(
          button: true,
          label: semanticLabel,
          selected: selected,
          child: InkWell(
            onTap: () => onSelectTab(index),
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: logoSize,
              child: Center(
                child: AnimatedScale(
                  scale: selected ? 1.08 : 0.96,
                  duration: const Duration(milliseconds: 180),
                  child: Opacity(
                    opacity: selected ? 1 : 0.78,
                    child: Image.asset(
                      asset,
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Schwebende Pill — große Icons, ohne Labels.
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StarBalancePill.fill.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: StarBalancePill.border.withValues(alpha: 0.95),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: StarBalancePill.glow.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              item(
                index: 0,
                semanticLabel: t.home,
                asset: HubScreen.homeLogo,
              ),
              item(
                index: 1,
                semanticLabel: t.puzzle,
                asset: HubScreen.puzzleLogo,
              ),
              item(
                index: 2,
                semanticLabel: t.color,
                asset: HubScreen.coloringLogo,
              ),
              item(
                index: 3,
                semanticLabel: t.events,
                asset: HubScreen.eventsLogo,
              ),
              item(
                index: 4,
                semanticLabel: t.favorites,
                asset: FavoriteStarButton.asset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

GallerySection? _gallerySectionForEvent(GalleryCatalog catalog, String eventId) {
  for (final section in catalog.pastEvents) {
    if (section.id == eventId) return section;
  }
  for (final section in catalog.activeEvents) {
    if (section.id == eventId) return section;
  }
  return null;
}

/// Events: laufende Hubs vorne, danach Letztes Event / Archiv.
class _EventsTab extends StatelessWidget {
  const _EventsTab({
    required this.catalog,
    required this.onOpenEvent,
  });

  final _HubCatalog catalog;
  final void Function(
    ContentEvent event,
    GallerySection coloring,
    GallerySection puzzle,
  ) onOpenEvent;

  List<({ContentEvent event, GallerySection coloring, GallerySection puzzle})>
      _entriesFor(Iterable<ContentEvent> events) {
    final out =
        <({ContentEvent event, GallerySection coloring, GallerySection puzzle})>[];
    for (final event in events) {
      final coloring = _gallerySectionForEvent(catalog.coloring, event.id);
      final puzzle = _gallerySectionForEvent(catalog.puzzle, event.id);
      if (coloring == null || puzzle == null) continue;
      if (coloring.pages.isEmpty && puzzle.pages.isEmpty) continue;
      out.add((event: event, coloring: coloring, puzzle: puzzle));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final layout = AppLayout.of(context);
    final live = _entriesFor(catalog.tags.activeEvents());
    final past = _entriesFor(catalog.tags.pastEvents());

    if (live.isEmpty && past.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t.eventsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: layout.isTablet ? 18 : 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);
    // Gleiche feste Höhe wie Galerie-Kacheln — egal Portrait/Landscape.
    final tileHeight = layout.isLandscape
        ? layout.galleryTileHeight
        : (size.width * 0.72).clamp(210.0, 300.0);
    final hubWidth = layout.isLandscape
        ? (tileHeight * 0.92).clamp(tileHeight * 0.78, tileHeight * 1.12)
        : (tileHeight * 1.05).clamp(tileHeight * 0.9, size.width * 0.88);

    Widget sectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Text(
          title,
          style: TextStyle(
            color: const Color(0xFFFFE7A0),
            fontSize: layout.isTablet ? 24 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            shadows: const [
              Shadow(color: Color(0xAA000000), blurRadius: 8),
            ],
          ),
        ),
      );
    }

    Widget portalFor(
      ({ContentEvent event, GallerySection coloring, GallerySection puzzle})
          entry, {
      String? subtitle,
      int index = 0,
    }) {
      return SizedBox(
        width: hubWidth,
        height: tileHeight,
        child: EventHubPortal(
          title: entry.event.title,
          subtitle: subtitle,
          imagePaths: [
            for (final p in entry.coloring.pages) p.assetPath,
            for (final p in entry.puzzle.pages) p.assetPath,
          ],
          accent: entry.event.id.toLowerCase().contains('halloween')
              ? const Color(0xFFFF8C42)
              : const Color(0xFFE8A0BF),
          isHalloween: entry.event.id.toLowerCase().contains('halloween'),
          brightenImage:
              entry.event.id.toLowerCase().contains('halloween'),
          slideOffset: Duration(milliseconds: 400 * index),
          onTap: () => onOpenEvent(
            entry.event,
            entry.coloring,
            entry.puzzle,
          ),
        ),
      );
    }

    // Vorne: laufende Events, danach zuletzt beendete → ältere.
    final rowItems = <({
      ({ContentEvent event, GallerySection coloring, GallerySection puzzle})
          entry,
      String subtitle,
    })>[
      for (final e in live) (entry: e, subtitle: t.eventsLive),
      if (past.isNotEmpty) ...[
        (entry: past.first, subtitle: t.lastEvent),
        for (final e in past.skip(1)) (entry: e, subtitle: t.eventsArchive),
      ],
    ];

    if (layout.isLandscape) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionTitle(live.isNotEmpty ? t.eventsLive : t.events),
          Expanded(
            child: Align(
              alignment: const Alignment(0, 0.15),
              child: SizedBox(
                height: tileHeight,
                child: ListView.separated(
                  key: const PageStorageKey<String>('hub_events_row'),
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
                  itemCount: rowItems.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: size.width * 0.03),
                  itemBuilder: (context, index) {
                    final item = rowItems[index];
                    return portalFor(
                      item.entry,
                      subtitle: item.subtitle,
                      index: index,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      );
    }

    final scrollBottom = MediaQuery.paddingOf(context).bottom;
    return ListView(
      key: const PageStorageKey<String>('hub_events_list'),
      padding: EdgeInsets.fromLTRB(
        layout.hubHorizontalPadding * 0.55,
        8,
        layout.hubHorizontalPadding * 0.55,
        20 + scrollBottom,
      ),
      children: [
        if (live.isNotEmpty) ...[
          sectionTitle(t.eventsLive),
          for (var i = 0; i < live.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Center(
              child: portalFor(
                live[i],
                subtitle: t.eventsLive,
                index: i,
              ),
            ),
          ],
          if (past.isNotEmpty) const SizedBox(height: 18),
        ],
        if (past.isNotEmpty) ...[
          sectionTitle(t.lastEvent),
          Center(
            child: portalFor(
              past.first,
              subtitle: t.lastEvent,
              index: live.length,
            ),
          ),
          if (past.length > 1) ...[
            const SizedBox(height: 18),
            sectionTitle(t.eventsArchive),
            for (var i = 1; i < past.length; i++) ...[
              if (i > 1) const SizedBox(height: 14),
              Center(
                child: portalFor(
                  past[i],
                  subtitle: t.eventsArchive,
                  index: live.length + i,
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }
}

/// Home: Live-Event-Kategorie (Bilder) → Zuletzt → Neu → …
/// Der Event-Hub selbst nur im Events-Tab.
class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.catalog,
    required this.scrollController,
    required this.onOpenColoring,
    required this.onOpenPuzzle,
    required this.onOpenPixel,
  });

  final _HubCatalog catalog;
  final ScrollController scrollController;
  final ValueChanged<ColoringPage> onOpenColoring;
  final ValueChanged<ColoringPage> onOpenPuzzle;
  final ValueChanged<ColoringPage> onOpenPixel;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  static const _homePreviewCount = 12;

  bool _precacheDone = false;
  String? _previewDayKey;
  List<ColoringPage> _previewPuzzles = const [];
  List<ColoringPage> _previewColoring = const [];
  List<ColoringPage> _previewPixel = const [];
  List<ColoringPage> _previewFavPuzzles = const [];
  List<ColoringPage> _previewFavColoring = const [];

  /// Tägliche Rotation: Fenster wandert durch den Pool, damit jedes Bild drankommt.
  List<ColoringPage> _dailyTake(List<ColoringPage> pages, String salt) {
    if (pages.isEmpty) return const [];
    final sorted = [...pages]..sort((a, b) => a.id.compareTo(b.id));
    final now = DateTime.now();
    final dayIndex = DateTime(now.year, now.month, now.day)
        .difference(DateTime(2024, 1, 1))
        .inDays;
    final saltHash = salt.hashCode & 0x7fffffff;
    final start = (dayIndex * _homePreviewCount + saltHash) % sorted.length;
    final count = math.min(_homePreviewCount, sorted.length);
    return [
      for (var i = 0; i < count; i++) sorted[(start + i) % sorted.length],
    ];
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

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
    // Advent-Unlocks / Season → Hub neu bauen (Sperren, Event-Zeile).
    context.watch<AdventService>();
    final pixelReady = context.watch<PixelReadyStore>();
    final coloringProgress = context.watch<ColoringProgressStore>();
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

    // Aktives Event: Kategorie oben auf Home (nur Bildzeilen, kein Hub).
    final liveEvents = <({
      ContentEvent event,
      GallerySection coloring,
      GallerySection puzzle,
    })>[];
    for (final event in tags.activeEvents()) {
      final coloring = _gallerySectionForEvent(
        widget.catalog.coloring,
        event.id,
      );
      final puzzle = _gallerySectionForEvent(widget.catalog.puzzle, event.id);
      if (coloring == null || puzzle == null) continue;
      if (coloring.pages.isEmpty && puzzle.pages.isEmpty) continue;
      liveEvents.add((event: event, coloring: coloring, puzzle: puzzle));
    }
    // Event-Motive nie unter „Neu“.
    final eventPageIds = <String>{
      for (final event in tags.allEvents()) ...[
        ...event.coloringIds,
        ...event.puzzleIds,
      ],
    };

    // Event-Motive und Advent-Geschenke gehören nicht unter „Neu“ —
    // nur echte New-Badges (max. 14 Tage), nie dauerhaft.
    final taggedNewColoring = allColoring
        .where((p) => tags.isNewColoring(p.id) && !eventPageIds.contains(p.id))
        .toList();
    final taggedNewPuzzles = allPuzzles
        .where((p) => tags.isNewPuzzle(p.id) && !eventPageIds.contains(p.id))
        .toList();
    final newColoring = taggedNewColoring;
    final newPuzzles = taggedNewPuzzles;
    final taggedNewIds = {
      for (final p in taggedNewColoring) p.id,
      for (final p in taggedNewPuzzles) p.id,
    };
    final highlightIds = {
      ...eventPageIds,
      for (final p in newColoring) p.id,
      for (final p in newPuzzles) p.id,
    };

    final regularPuzzlesPool =
        allPuzzles.where((p) => !highlightIds.contains(p.id)).toList();
    final regularColoringPool =
        allColoring.where((p) => !highlightIds.contains(p.id)).toList();
    final readyPixelPool = [
      for (final p in allColoring)
        if (pixelReady.isReadyFor(p.id) && coloringProgress.hasProgress(p.id))
          p,
    ];
    final dayKey = _todayKey();
    if (_previewDayKey != dayKey) {
      _previewDayKey = dayKey;
      _previewPuzzles = _dailyTake(regularPuzzlesPool, 'puzzle');
      _previewColoring = _dailyTake(regularColoringPool, 'color');
      _previewPixel = _dailyTake(readyPixelPool, 'pixel');
      _previewFavPuzzles = _dailyTake(favPuzzles, 'fav_puzzle');
      _previewFavColoring = _dailyTake(favColoring, 'fav_color');
    } else {
      // Pools können nachladen (Favoriten / neu fertige Pixel).
      if (_previewPuzzles.isEmpty && regularPuzzlesPool.isNotEmpty) {
        _previewPuzzles = _dailyTake(regularPuzzlesPool, 'puzzle');
      }
      if (_previewColoring.isEmpty && regularColoringPool.isNotEmpty) {
        _previewColoring = _dailyTake(regularColoringPool, 'color');
      }
      if (_previewPixel.isEmpty && readyPixelPool.isNotEmpty) {
        _previewPixel = _dailyTake(readyPixelPool, 'pixel');
      }
      if (_previewFavPuzzles.isEmpty && favPuzzles.isNotEmpty) {
        _previewFavPuzzles = _dailyTake(favPuzzles, 'fav_puzzle');
      }
      if (_previewFavColoring.isEmpty && favColoring.isNotEmpty) {
        _previewFavColoring = _dailyTake(favColoring, 'fav_color');
      }
    }
    final halloweenColor = tags.halloweenColoring;
    final halloweenPuzzle = tags.halloweenPuzzle;

    final scrollBottom = MediaQuery.paddingOf(context).bottom;
    final primaryLive = liveEvents.isEmpty ? null : liveEvents.first;
    final livePuzzlePreview = primaryLive == null
        ? const <ColoringPage>[]
        : tags.sortNewestFirst(
            primaryLive.puzzle.pages.toList(growable: false),
            coloring: false,
          );
    final liveColorPreview = primaryLive == null
        ? const <ColoringPage>[]
        : tags.sortNewestFirst(
            primaryLive.coloring.pages.toList(growable: false),
            coloring: true,
          );

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.only(bottom: 16 + scrollBottom),
      children: [
        // Event-Kategorie oben — nur Puzzle/Color-Zeilen, Hub nur unter Events.
        if (primaryLive != null) ...[
          _SectionHeader(title: primaryLive.event.title),
          // Komplette Winter-/Merry-Christmas-Galerie (kein Preview-Limit).
          if (livePuzzlePreview.isNotEmpty)
            _HomeRow(
              label: t.puzzle,
              pages: livePuzzlePreview,
              isNew: (_) => false,
              isHalloween: (id) => halloweenPuzzle.contains(id),
              requiresAdUnlock: (id) => EventContentGate.isGatedId(
                tags,
                id,
                kind: FavoriteKind.puzzle,
              ),
              favoriteKind: FavoriteKind.puzzle,
              showPreviewButton: true,
              onOpen: widget.onOpenPuzzle,
            ),
          if (liveColorPreview.isNotEmpty)
            _HomeRow(
              label: t.color,
              pages: liveColorPreview,
              isNew: (_) => false,
              isHalloween: (id) => halloweenColor.contains(id),
              requiresAdUnlock: (id) => EventContentGate.isGatedId(
                tags,
                id,
                kind: FavoriteKind.coloring,
              ),
              favoriteKind: FavoriteKind.coloring,
              onOpen: widget.onOpenColoring,
            ),
          const SizedBox(height: 8),
        ],
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
            requiresAdUnlock: (id, kind) =>
                EventContentGate.isGatedId(tags, id, kind: kind),
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
              // Advent-Freischaltungen ohne New-Badge.
              isNew: (id) => taggedNewIds.contains(id) && tags.isNewPuzzle(id),
              isHalloween: (id) => halloweenPuzzle.contains(id),
              requiresAdUnlock: (id) => EventContentGate.isGatedId(
                tags,
                id,
                kind: FavoriteKind.puzzle,
              ),
              favoriteKind: FavoriteKind.puzzle,
              showPreviewButton: true,
              onOpen: widget.onOpenPuzzle,
            ),
          if (newColoring.isNotEmpty)
            _HomeRow(
              label: t.newColor,
              pages: newColoring,
              isNew: (id) =>
                  taggedNewIds.contains(id) && tags.isNewColoring(id),
              isHalloween: (id) => halloweenColor.contains(id),
              requiresAdUnlock: (id) => EventContentGate.isGatedId(
                tags,
                id,
                kind: FavoriteKind.coloring,
              ),
              favoriteKind: FavoriteKind.coloring,
              onOpen: widget.onOpenColoring,
            ),
          const SizedBox(height: 8),
        ],
        if (favPuzzles.isNotEmpty || favColoring.isNotEmpty) ...[
          _SectionHeader(title: t.favorites),
          if (_previewFavPuzzles.isNotEmpty)
            _HomeRow(
              label: t.puzzle,
              pages: _previewFavPuzzles,
              isNew: (id) => tags.isNewPuzzle(id),
              isHalloween: (id) => halloweenPuzzle.contains(id),
              requiresAdUnlock: (id) => EventContentGate.isGatedId(
                tags,
                id,
                kind: FavoriteKind.puzzle,
              ),
              favoriteKind: FavoriteKind.puzzle,
              showPreviewButton: true,
              onOpen: widget.onOpenPuzzle,
            ),
          if (_previewFavColoring.isNotEmpty)
            _HomeRow(
              label: t.color,
              pages: _previewFavColoring,
              isNew: (id) => tags.isNewColoring(id),
              isHalloween: (id) => halloweenColor.contains(id),
              requiresAdUnlock: (id) => EventContentGate.isGatedId(
                tags,
                id,
                kind: FavoriteKind.coloring,
              ),
              favoriteKind: FavoriteKind.coloring,
              onOpen: widget.onOpenColoring,
            ),
          const SizedBox(height: 8),
        ],
        if (_previewPuzzles.isNotEmpty) ...[
          _SectionHeader(
            title: t.puzzle,
            logoAsset: HubScreen.puzzleLogo,
          ),
          _HomeRow(
            pages: _previewPuzzles,
            isNew: (id) => tags.isNewPuzzle(id),
            isHalloween: (id) => halloweenPuzzle.contains(id),
            requiresAdUnlock: (id) => EventContentGate.isGatedId(
              tags,
              id,
              kind: FavoriteKind.puzzle,
            ),
            favoriteKind: FavoriteKind.puzzle,
            showPreviewButton: true,
            onOpen: widget.onOpenPuzzle,
          ),
        ],
        if (_previewColoring.isNotEmpty) ...[
          _SectionHeader(
            title: t.color,
            logoAsset: HubScreen.coloringLogo,
          ),
          _HomeRow(
            pages: _previewColoring,
            isNew: (id) => tags.isNewColoring(id),
            isHalloween: (id) => halloweenColor.contains(id),
            requiresAdUnlock: (id) => EventContentGate.isGatedId(
              tags,
              id,
              kind: FavoriteKind.coloring,
            ),
            favoriteKind: FavoriteKind.coloring,
            onOpen: widget.onOpenColoring,
          ),
        ],
        if (_previewPixel.isNotEmpty) ...[
          _SectionHeader(
            title: t.readyForPixel,
            logoAsset: HubScreen.pixelLogo,
          ),
          _HomeRow(
            pages: _previewPixel,
            isNew: (_) => false,
            isHalloween: (id) => halloweenColor.contains(id),
            requiresAdUnlock: (_) => false,
            favoriteKind: FavoriteKind.coloring,
            showFavoriteButton: false,
            onOpen: widget.onOpenPixel,
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.logoAsset});

  final String title;
  final String? logoAsset;

  @override
  Widget build(BuildContext context) {
    final isTablet = AppLayout.of(context).isTablet;
    final logoSize = isTablet ? 48.0 : 42.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          if (logoAsset != null) ...[
            Image.asset(
              logoAsset!,
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
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
          ),
        ],
      ),
    );
  }
}

class _HomeRecentRow extends StatelessWidget {
  const _HomeRecentRow({
    required this.items,
    required this.isNew,
    required this.isHalloween,
    required this.requiresAdUnlock,
    required this.onOpenColoring,
    required this.onOpenPuzzle,
  });

  final List<({ColoringPage page, FavoriteKind kind})> items;
  final bool Function(String id, FavoriteKind kind) isNew;
  final bool Function(String id, FavoriteKind kind) isHalloween;
  final bool Function(String id, FavoriteKind kind) requiresAdUnlock;
  final ValueChanged<ColoringPage> onOpenColoring;
  final ValueChanged<ColoringPage> onOpenPuzzle;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final rowHeight = layout.isLandscape
        ? (size.height * 0.36).clamp(160.0, 260.0)
        : (size.height * 0.24).clamp(148.0, layout.isTablet ? 248.0 : 204.0);

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        key: const PageStorageKey<String>('home_recent_row'),
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
              showPreviewButton: kind == FavoriteKind.puzzle,
              favoriteKind: kind,
              softShadow: true,
              requiresAdUnlock: requiresAdUnlock(page.id, kind),
              starLockCost: context.watch<StarWalletStore>().requiresStars(
                        page.id,
                        kind,
                      )
                  ? context.read<StarWalletStore>().unlockCost(page.id, kind)
                  : null,
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
    required this.requiresAdUnlock,
    required this.favoriteKind,
    required this.onOpen,
    this.label,
    this.showPreviewButton = false,
    this.showFavoriteButton = true,
  });

  final List<ColoringPage> pages;
  final String? label;
  final bool Function(String id) isNew;
  final bool Function(String id) isHalloween;
  final bool Function(String id) requiresAdUnlock;
  final FavoriteKind favoriteKind;
  final ValueChanged<ColoringPage> onOpen;
  final bool showPreviewButton;
  final bool showFavoriteButton;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    // Portrait: etwas höhere Reihen (mehr Fläche), Landscape: flacher.
    final rowHeight = layout.isLandscape
        ? (size.height * 0.36).clamp(160.0, 260.0)
        : (size.height * 0.24).clamp(148.0, layout.isTablet ? 248.0 : 204.0);

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
            key: PageStorageKey<String>(
              'home_row_${favoriteKind.name}_${label ?? 'main'}',
            ),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
            itemCount: pages.length,
            separatorBuilder: (_, _) => SizedBox(width: size.width * 0.032),
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
                  showFavoriteButton: showFavoriteButton,
                  showPreviewButton: showPreviewButton,
                  favoriteKind: favoriteKind,
                  softShadow: true,
                  requiresAdUnlock: requiresAdUnlock(page.id),
                  starLockCost: context
                          .watch<StarWalletStore>()
                          .requiresStars(page.id, favoriteKind)
                      ? context
                          .read<StarWalletStore>()
                          .unlockCost(page.id, favoriteKind)
                      : null,
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
  const _StickerBookButton({
    required this.onPressed,
    this.winter = false,
    this.size = 56,
  });

  final VoidCallback onPressed;
  final bool winter;
  final double size;

  static const classicAsset = 'assets/images/buch_icon.png';
  static const winterAsset = 'assets/images/christmas.album.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: winter ? 'Christmas album' : 'Sticker album',
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            winter ? winterAsset : classicAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class _AdventMenuButton extends StatefulWidget {
  const _AdventMenuButton({
    required this.onPressed,
    this.onLongPress,
    this.compact = false,
    this.micro = false,
  });

  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool compact;
  final bool micro;

  @override
  State<_AdventMenuButton> createState() => _AdventMenuButtonState();
}

class _AdventMenuButtonState extends State<_AdventMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _syncPulse(bool active) {
    if (active) {
      if (!_pulse.isAnimating) unawaited(_pulse.repeat());
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final advent = context.watch<AdventService>();
    final side = MediaQuery.sizeOf(context).shortestSide;
    final size = side >= 600
        ? 88.0
        : (widget.micro ? 58.0 : (widget.compact ? 68.0 : 78.0));
    final badge = advent.openableUnopenedCount;
    final shouldPulse = badge > 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncPulse(shouldPulse);
    });

    return Semantics(
      button: true,
      label: t.adventCalendar,
      child: GestureDetector(
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    if (!shouldPulse) return child!;
                    // Sanftes Atmen: leichte Scale + Glow (nicht das harte Klopfen).
                    final breath =
                        0.5 + 0.5 * math.sin(_pulse.value * math.pi * 2);
                    final scale = 1.0 + 0.06 * breath;
                    final glow = 0.22 + 0.38 * breath;
                    return Transform.scale(
                      scale: scale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD56A)
                                  .withValues(alpha: glow),
                              blurRadius: 10 + 10 * breath,
                              spreadRadius: 1 + 2.5 * breath,
                            ),
                            BoxShadow(
                              color: const Color(0xFFFFF4C8)
                                  .withValues(alpha: glow * 0.4),
                              blurRadius: 5 + 4 * breath,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Image.asset(
                    HubScreen.adventButtonAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE85D5D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Text(
                      '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
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

class _PlainIconButton extends StatelessWidget {
  const _PlainIconButton({
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.asset,
    this.size = 28,
    this.dense = false,
  }) : assert(icon != null || asset != null);

  final String semanticLabel;
  final IconData? icon;
  final String? asset;
  final VoidCallback onPressed;
  final double size;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final child = asset != null
        ? Image.asset(
            asset!,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          )
        : Icon(
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
          );
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(dense ? 2 : 6),
            child: child,
          ),
        ),
      ),
    );
  }
}
