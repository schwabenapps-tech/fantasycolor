import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob-IDs für Fairy Fantasy Color.
///
/// Release/Profile: echte IDs. Debug: Google-Testanzeigen.
class AdsConfig {
  AdsConfig._();

  /// false = echte AdMob-IDs in Release/Profile.
  /// Debug-Builds nutzen weiterhin Google-Testanzeigen (siehe Getter).
  static const bool useTestAds = false;

  // --- Echte IDs ---
  static const String androidAppId = 'ca-app-pub-5511264969083689~6262583566';
  static const String iosAppId = 'ca-app-pub-5511264969083689~7192521859';
  static const String androidInterstitialUnitId =
      'ca-app-pub-5511264969083689/1038177048';
  static const String iosInterstitialUnitId =
      'ca-app-pub-5511264969083689/6052673887';
  static const String androidRewardedUnitId =
      'ca-app-pub-5511264969083689/2435556563';
  static const String iosRewardedUnitId =
      'ca-app-pub-5511264969083689/6473827747';

  // Google Sample / Test
  static const String _testAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String _testIosAppId = 'ca-app-pub-3940256099942544~1458002511';
  static const String _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testAndroidRewarded =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosRewarded =
      'ca-app-pub-3940256099942544/1712485313';

  static String get appId {
    if (useTestAds || kDebugMode) {
      return Platform.isIOS ? _testIosAppId : _testAndroidAppId;
    }
    return Platform.isIOS ? iosAppId : androidAppId;
  }

  static String get interstitialAdUnitId {
    if (useTestAds || kDebugMode) {
      return Platform.isIOS ? _testIosInterstitial : _testAndroidInterstitial;
    }
    return Platform.isIOS ? iosInterstitialUnitId : androidInterstitialUnitId;
  }

  static String get rewardedAdUnitId {
    if (useTestAds || kDebugMode) {
      return Platform.isIOS ? _testIosRewarded : _testAndroidRewarded;
    }
    final live = Platform.isIOS ? iosRewardedUnitId : androidRewardedUnitId;
    if (live.isEmpty) {
      return Platform.isIOS ? _testIosRewarded : _testAndroidRewarded;
    }
    return live;
  }
}
