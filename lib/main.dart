import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/coloring_progress_store.dart';
import 'providers/favorites_store.dart';
import 'screens/start_screen.dart';
import 'services/ads_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Ads asynchron — App startet nicht erst nach AdMob.
  unawaited(AdsService.initialize());

  final favorites = FavoritesStore();
  await favorites.load();

  final progress = ColoringProgressStore();
  await progress.load();

  runApp(
    FantasyColorApp(
      favorites: favorites,
      progress: progress,
    ),
  );
}

class FantasyColorApp extends StatelessWidget {
  const FantasyColorApp({
    super.key,
    this.favorites,
    this.progress,
  });

  /// Wenn null (z. B. Tests), werden leere Stores erzeugt.
  final FavoritesStore? favorites;
  final ColoringProgressStore? progress;

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
      ],
      child: MaterialApp(
        title: 'Fantasy Color',
        debugShowCheckedModeBanner: false,
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
