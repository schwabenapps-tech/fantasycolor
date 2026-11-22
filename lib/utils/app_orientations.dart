import 'package:flutter/services.dart';

/// Menüs (Splash/Hub/Galerien/Favoriten) = Hochkant.
/// Play (Ausmalen/Puzzle/Pixel + Puzzle-Vorschau) = drehbar.
abstract final class AppOrientations {
  static const all = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static const portraitOnly = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ];

  /// Geschachtelte Play-Surfaces (Vorschau → Puzzle, Coloring → Puzzle, …).
  static int _playDepth = 0;

  static Future<void> lockHubPortrait() =>
      SystemChrome.setPreferredOrientations(portraitOnly);

  /// Ausmalen / Puzzle / Pixel / Puzzle-Vorschau — Drehen erlaubt.
  static Future<void> enterPlay() {
    _playDepth++;
    return SystemChrome.setPreferredOrientations(all);
  }

  /// Zurück zu Menü — wieder Hochkant.
  /// Delayed, damit pushReplacement / Vorschau→Play nicht kurz Portrait erzwingt.
  static Future<void> leavePlay() {
    if (_playDepth > 0) _playDepth--;
    return Future<void>.delayed(Duration.zero, () async {
      if (_playDepth == 0) {
        await SystemChrome.setPreferredOrientations(portraitOnly);
      }
    });
  }
}
