import 'dart:async';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'data/coloring_pages_loader.dart';
import 'data/puzzle_images_loader.dart';
import 'firebase_options.dart';
import 'providers/coloring_progress_store.dart';
import 'providers/favorites_store.dart';
import 'providers/feedback_survey_store.dart';
import 'providers/pixel_mode_unlock_store.dart';
import 'providers/pixel_progress_store.dart';
import 'providers/pixel_ready_store.dart';
import 'providers/recent_content_store.dart';
import 'providers/star_wallet_store.dart';
import 'providers/sticker_collection_store.dart';
import 'screens/hub_screen.dart';
import 'screens/start_screen.dart';
import 'providers/coloring_sticker_placements_store.dart';
import 'services/ads_service.dart';
import 'services/advent_service.dart';
import 'services/analytics_service.dart';
import 'services/app_update_service.dart';
import 'services/audio_service.dart';
import 'services/consent_service.dart';
import 'services/daily_quest_service.dart';
import 'services/deep_link_service.dart';
import 'services/device_id_service.dart';
import 'services/notification_service.dart';
import 'services/remote_pack_service.dart';
import 'services/streak_service.dart';
import 'utils/app_orientations.dart';
import 'utils/app_page_route.dart';
import 'utils/app_route_observer.dart';
import 'utils/image_source.dart';
import 'widgets/force_update_overlay.dart';

/// Hintergrund hinter dem ersten Flutter-Frame (Splash / Gaps).
const _bootBackground = Color(0xFF12263F);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseReady = await _initFirebaseBestEffort();
  // Anonyme Geräte-ID lokal erzeugen/laden; bei Deinstallation weg.
  await DeviceIdService.instance.ensureInitialized(bindFirebase: firebaseReady);
  if (firebaseReady) {
    FlutterError.onError = (details) {
      // Fehlende Pack-/Progress-Bilder: UI fängt das ab — nicht als fatal melden.
      if (isBenignImageLoadError(details.exception)) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
        return;
      }
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      final fatal = !isBenignImageLoadError(error);
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
      return true;
    };
    unawaited(AnalyticsService.instance.initialize());
    unawaited(_logAppOpenBestEffort());
  }

  // Start erlaubt Hochkant + Quer — Splash hat beide Motive.
  await Future.wait([
    AppOrientations.lockHubPortrait(),
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    DeepLinkService.instance.initialize(),
  ]);

  final favorites = FavoritesStore();
  final progress = ColoringProgressStore();
  final pixelUnlock = PixelModeUnlockStore();
  final pixelProgress = PixelProgressStore();
  final pixelReady = PixelReadyStore();
  final stickers = StickerCollectionStore();
  final recent = RecentContentStore();
  final stars = StarWalletStore();
  final dailyQuest = DailyQuestService();
  final feedbackSurvey = FeedbackSurveyStore();

  // Schwere Init erst nach dem ersten Frame — UI darf nie am Boot hängen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AdsService.initialize());
    unawaited(AudioService.instance.initialize());
    unawaited(StreakService.instance.load());
    unawaited(NotificationService.instance.initialize());
    unawaited(favorites.load());
    unawaited(progress.load());
    unawaited(pixelUnlock.load());
    unawaited(pixelProgress.load());
    unawaited(pixelReady.load());
    unawaited(recent.load());
    unawaited(stars.load());
    unawaited(feedbackSurvey.load());
    unawaited(() async {
      await stickers.load();
      await RemotePackService.instance.sync();
      await stickers.reloadCatalog();
      final coloring = await loadColoringPages(shuffle: false);
      final puzzles = await loadPuzzleImages(shuffle: false);
      final pools = await DailyQuestService.freePools(
        allColoring: [for (final p in coloring) p.id],
        allPuzzle: [for (final p in puzzles) p.id],
      );
      await pixelReady.load();
      await pixelProgress.load();
      await stars.load();
      final readyIds = pixelReady.ids.toList(growable: false);
      final inProgressIds = pixelProgress.inProgressIds;
      final hasLocked = DailyQuestService.hasStarLockedContent(
        wallet: stars,
        allColoring: [for (final p in coloring) p.id],
        allPuzzle: [for (final p in puzzles) p.id],
      );
      final eventIds = await DailyQuestService.activeEventColoringIds();
      await dailyQuest.load(
        freeColoringIds: pools.coloring,
        freePuzzleIds: pools.puzzle,
        pixelReadyIds: readyIds,
        pixelInProgressIds: inProgressIds,
        finishedColoringIds: readyIds,
        eventColoringIds: eventIds,
        hasStarLockedContent: hasLocked,
        adventDoorAvailable: DailyQuestService.adventDoorAvailableNow(),
      );
    }());
    unawaited(WakelockPlus.enable());
  });

  runApp(
    FantasyColorApp(
      favorites: favorites,
      progress: progress,
      pixelUnlock: pixelUnlock,
      pixelProgress: pixelProgress,
      pixelReady: pixelReady,
      stickers: stickers,
      recent: recent,
      stars: stars,
      dailyQuest: dailyQuest,
      feedbackSurvey: feedbackSurvey,
    ),
  );
}

Future<bool> _initFirebaseBestEffort() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (e, st) {
    debugPrint('Firebase.initializeApp failed: $e\n$st');
    return false;
  }
}

Future<void> _logAppOpenBestEffort() async {
  try {
    await FirebaseAnalytics.instance.logAppOpen();
  } catch (e, st) {
    debugPrint('FirebaseAnalytics.logAppOpen failed: $e\n$st');
  }
}

class FantasyColorApp extends StatefulWidget {
  const FantasyColorApp({
    super.key,
    this.favorites,
    this.progress,
    this.pixelUnlock,
    this.pixelProgress,
    this.pixelReady,
    this.stickers,
    this.recent,
    this.stars,
    this.dailyQuest,
    this.feedbackSurvey,
  });

  /// Wenn null (z. B. Tests), werden leere Stores erzeugt.
  final FavoritesStore? favorites;
  final ColoringProgressStore? progress;
  final PixelModeUnlockStore? pixelUnlock;
  final PixelProgressStore? pixelProgress;
  final PixelReadyStore? pixelReady;
  final StickerCollectionStore? stickers;
  final RecentContentStore? recent;
  final StarWalletStore? stars;
  final DailyQuestService? dailyQuest;
  final FeedbackSurveyStore? feedbackSurvey;

  @override
  State<FantasyColorApp> createState() => _FantasyColorAppState();
}

class _FantasyColorAppState extends State<FantasyColorApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Einmalig halten — niemals `?? Store()` im build (sonst leerer Store ohne load).
  late final FavoritesStore _favorites =
      widget.favorites ?? FavoritesStore();
  late final ColoringProgressStore _progress =
      widget.progress ?? ColoringProgressStore();
  late final PixelModeUnlockStore _pixelUnlock =
      widget.pixelUnlock ?? PixelModeUnlockStore();
  late final PixelProgressStore _pixelProgress =
      widget.pixelProgress ?? PixelProgressStore();
  late final PixelReadyStore _pixelReady =
      widget.pixelReady ?? PixelReadyStore();
  late final StickerCollectionStore _stickers =
      widget.stickers ?? StickerCollectionStore();
  late final RecentContentStore _recent =
      widget.recent ?? RecentContentStore();
  late final StarWalletStore _stars = widget.stars ?? StarWalletStore();
  late final DailyQuestService _dailyQuest =
      widget.dailyQuest ?? DailyQuestService();
  late final FeedbackSurveyStore _feedbackSurvey =
      widget.feedbackSurvey ?? FeedbackSurveyStore();
  late final ColoringStickerPlacementsStore _stickerPlacements =
      ColoringStickerPlacementsStore();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DeepLinkService.instance.onOpenHub = _openHubFromDeepLink;
    // Force-Update-Check hier (nicht nur in main): Listener sind gemountet,
    // und der Check läuft zuverlässig nach dem ersten Frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppUpdateService.instance.check());
      unawaited(AdventService.instance.load());
    });
    if (widget.stickers == null) {
      unawaited(_stickers.load());
    }
    if (widget.stars == null) {
      unawaited(_stars.load());
    }
    if (widget.dailyQuest == null) {
      unawaited(_dailyQuest.load());
    }
    if (widget.feedbackSurvey == null) {
      unawaited(_feedbackSurvey.load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (identical(DeepLinkService.instance.onOpenHub, _openHubFromDeepLink)) {
      DeepLinkService.instance.onOpenHub = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(AudioService.instance.pauseForBackground());
        unawaited(WakelockPlus.disable());
      case AppLifecycleState.resumed:
        unawaited(AudioService.instance.resumeFromBackground());
        unawaited(WakelockPlus.enable());
        unawaited(AppUpdateService.instance.check(forceRefresh: true));
        // Neue Remote-Packs (Coloring/Puzzle/Stickers) ohne App-Neustart ziehen.
        unawaited(() async {
          await RemotePackService.instance.sync();
          await _stickers.reloadCatalog();
        }());
    }
  }

  void _openHubFromDeepLink() {
    DeepLinkService.instance.consumePendingOpenHub();
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    unawaited(AppOrientations.lockHubPortrait());
    nav.popUntil((route) => route.isFirst);
    nav.push(
      AppPageRoute<void>(
        builder: (_) => const HubScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Provider hier (nicht nur in main), damit Hot-Reload den Baum mitnimmt.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _favorites),
        ChangeNotifierProvider.value(value: _progress),
        ChangeNotifierProvider.value(value: _pixelUnlock),
        ChangeNotifierProvider.value(value: _pixelProgress),
        ChangeNotifierProvider.value(value: _pixelReady),
        ChangeNotifierProvider.value(value: _stickers),
        ChangeNotifierProvider.value(value: _recent),
        ChangeNotifierProvider.value(value: _stars),
        ChangeNotifierProvider.value(value: _dailyQuest),
        ChangeNotifierProvider.value(value: _feedbackSurvey),
        ChangeNotifierProvider.value(value: _stickerPlacements),
        ChangeNotifierProvider.value(
          value: AudioService.instance,
        ),
        ChangeNotifierProvider.value(
          value: ConsentService.instance,
        ),
        ChangeNotifierProvider.value(
          value: RemotePackService.instance,
        ),
        ChangeNotifierProvider.value(
          value: AppUpdateService.instance,
        ),
        ChangeNotifierProvider.value(
          value: StreakService.instance,
        ),
        ChangeNotifierProvider.value(
          value: AdventService.instance,
        ),
      ],
      child: MaterialApp(
        title: 'Fairy Fantasy Color',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        navigatorObservers: [
          if (Firebase.apps.isNotEmpty) AnalyticsService.instance.observer,
          appRouteObserver,
        ],
        // App-UI bewusst Englisch (Store/Produkt). Übersetzungs-Tabellen
        // bleiben für später; Gerätelocale steuert die UI vorerst nicht.
        locale: const Locale('en'),
        localeResolutionCallback: (locale, supported) => const Locale('en'),
        supportedLocales: const [Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B6FBF),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: _bootBackground,
          useMaterial3: true,
        ),
        builder: (context, child) {
          // ListenableBuilder statt context.watch im MaterialApp.builder —
          // zuverlässigeres Rebuild, wenn forceRequired umschaltet.
          return ListenableBuilder(
            listenable: AppUpdateService.instance,
            builder: (context, _) {
              final update = AppUpdateService.instance;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (child != null) child,
                  if (update.forceRequired)
                    Positioned.fill(
                      child: ForceUpdateOverlay(message: update.message),
                    ),
                ],
              );
            },
          );
        },
        home: const StartScreen(),
      ),
    );
  }
}
