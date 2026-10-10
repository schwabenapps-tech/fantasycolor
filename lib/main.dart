import 'dart:async';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/coloring_progress_store.dart';
import 'providers/favorites_store.dart';
import 'providers/pixel_mode_unlock_store.dart';
import 'providers/pixel_progress_store.dart';
import 'providers/sticker_collection_store.dart';
import 'screens/hub_screen.dart';
import 'screens/start_screen.dart';
import 'services/ads_service.dart';
import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/consent_service.dart';
import 'services/deep_link_service.dart';
import 'services/remote_pack_service.dart';
import 'utils/app_page_route.dart';

/// Hintergrund hinter dem ersten Flutter-Frame (Splash / Gaps).
const _bootBackground = Color(0xFF12263F);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseReady = await _initFirebaseBestEffort();
  if (firebaseReady) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    unawaited(AnalyticsService.instance.initialize());
    unawaited(_logAppOpenBestEffort());
  }

  // Start-Screen Landscape — parallel zu UI-Mode, damit Splash kürzer wirkt.
  await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]),
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    DeepLinkService.instance.initialize(),
  ]);

  final favorites = FavoritesStore();
  final progress = ColoringProgressStore();
  final pixelUnlock = PixelModeUnlockStore();
  final pixelProgress = PixelProgressStore();
  final stickers = StickerCollectionStore();

  // Schwere Init erst nach dem ersten Frame — UI darf nie am Boot hängen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AdsService.initialize());
    unawaited(AudioService.instance.initialize());
    unawaited(RemotePackService.instance.sync());
    unawaited(favorites.load());
    unawaited(progress.load());
    unawaited(pixelUnlock.load());
    unawaited(pixelProgress.load());
    unawaited(stickers.load());
  });

  runApp(
    FantasyColorApp(
      favorites: favorites,
      progress: progress,
      pixelUnlock: pixelUnlock,
      pixelProgress: pixelProgress,
      stickers: stickers,
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
    this.stickers,
  });

  /// Wenn null (z. B. Tests), werden leere Stores erzeugt.
  final FavoritesStore? favorites;
  final ColoringProgressStore? progress;
  final PixelModeUnlockStore? pixelUnlock;
  final PixelProgressStore? pixelProgress;
  final StickerCollectionStore? stickers;

  @override
  State<FantasyColorApp> createState() => _FantasyColorAppState();
}

class _FantasyColorAppState extends State<FantasyColorApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DeepLinkService.instance.onOpenHub = _openHubFromDeepLink;
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
      case AppLifecycleState.resumed:
        unawaited(AudioService.instance.resumeFromBackground());
    }
  }

  void _openHubFromDeepLink() {
    DeepLinkService.instance.consumePendingOpenHub();
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
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
        ChangeNotifierProvider.value(
          value: widget.favorites ?? FavoritesStore(),
        ),
        ChangeNotifierProvider.value(
          value: widget.progress ?? ColoringProgressStore(),
        ),
        ChangeNotifierProvider.value(
          value: widget.pixelUnlock ?? PixelModeUnlockStore(),
        ),
        ChangeNotifierProvider.value(
          value: widget.pixelProgress ?? PixelProgressStore(),
        ),
        ChangeNotifierProvider.value(
          value: widget.stickers ?? StickerCollectionStore(),
        ),
        ChangeNotifierProvider.value(
          value: AudioService.instance,
        ),
        ChangeNotifierProvider.value(
          value: ConsentService.instance,
        ),
        ChangeNotifierProvider.value(
          value: RemotePackService.instance,
        ),
      ],
      child: MaterialApp(
        title: 'Fairy Fantasy Color',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        navigatorObservers: [
          if (Firebase.apps.isNotEmpty) AnalyticsService.instance.observer,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B6FBF),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: _bootBackground,
          useMaterial3: true,
        ),
        home: const StartScreen(),
      ),
    );
  }
}
