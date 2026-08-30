import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob-IDs für Fantasy Color.
///
/// Solange die App in AdMob noch nicht verknüpft ist, laufen **Google-Test-IDs**.
/// Später echte App-/Unit-IDs hier eintragen und [useTestAds] auf false setzen.
class AdsConfig {
  AdsConfig._();

  /// true = offizielle Google-Testwerbung (sicher für Entwicklung).
  static const bool useTestAds = true;

  // --- Echte IDs eintragen, sobald AdMob verknüpft ist ---
  static const String androidAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';
  static const String iosAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';
  static const String androidInterstitialUnitId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String iosInterstitialUnitId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // Google Sample / Test
  static const String _testAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String _testIosAppId = 'ca-app-pub-3940256099942544~1458002511';
  static const String _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  static String get appId {
    if (useTestAds || kDebugMode && _looksPlaceholder(androidAppId)) {
      return Platform.isIOS ? _testIosAppId : _testAndroidAppId;
    }
    return Platform.isIOS ? iosAppId : androidAppId;
  }

  static String get interstitialAdUnitId {
    if (useTestAds || kDebugMode && _looksPlaceholder(androidInterstitialUnitId)) {
      return Platform.isIOS ? _testIosInterstitial : _testAndroidInterstitial;
    }
    return Platform.isIOS ? iosInterstitialUnitId : androidInterstitialUnitId;
  }

  static bool _looksPlaceholder(String id) => id.contains('XXXXXXXX');
}
