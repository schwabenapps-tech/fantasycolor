import 'dart:async';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/coloring_progress_store.dart';
import 'providers/favorites_store.dart';
import 'providers/pixel_mode_unlock_store.dart';
import 'providers/pixel_progress_store.dart';
import 'screens/start_screen.dart';
import 'services/ads_service.dart';
import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/consent_service.dart';
import 'services/remote_pack_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  unawaited(AnalyticsService.instance.initialize());
  unawaited(FirebaseAnalytics.instance.logAppOpen());

  // Start-Screen bleibt Landscape; danach gibt StartScreen alle Orientierungen frei.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Ads / Audio / Remote-Packs asynchron — App startet nicht erst danach.
  unawaited(AdsService.initialize());
  unawaited(AudioService.instance.initialize());
  unawaited(RemotePackService.instance.sync());

  final favorites = FavoritesStore();
  await favorites.load();

  // load() invalidiert nur Fortschritt von ausgetauschten Ausmalbildern.
  final progress = ColoringProgressStore();
  await progress.load();

  final pixelUnlock = PixelModeUnlockStore();
  await pixelUnlock.load();

  // load() invalidiert Pixel-Fortschritt nur für entfernte/geänderte Puzzle-Gallery.
  final pixelProgress = PixelProgressStore();
  await pixelProgress.load();

  runApp(
    FantasyColorApp(
      favorites: favorites,
      progress: progress,
      pixelUnlock: pixelUnlock,
      pixelProgress: pixelProgress,
    ),
  );
}

class FantasyColorApp extends StatelessWidget {
  const FantasyColorApp({
    super.key,
    this.favorites,
    this.progress,
    this.pixelUnlock,
    this.pixelProgress,
  });

  /// Wenn null (z. B. Tests), werden leere Stores erzeugt.
  final FavoritesStore? favorites;
  final ColoringProgressStore? progress;
  final PixelModeUnlockStore? pixelUnlock;
  final PixelProgressStore? pixelProgress;

  @override
  Widget build(BuildContext context) {
    // Provider hier (nicht nur in main), damit Hot-Reload den Baum mitnimmt.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: favorites ?? FavoritesStore(),
        ),
        ChangeNotifierProvider.value(
          value: progress ?? ColoringProgressStore(),
        ),
        ChangeNotifierProvider.value(
          value: pixelUnlock ?? PixelModeUnlockStore(),
        ),
        ChangeNotifierProvider.value(
          value: pixelProgress ?? PixelProgressStore(),
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
        navigatorObservers: [
          AnalyticsService.instance.observer,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B6FBF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const StartScreen(),
      ),
    );
  }
}
