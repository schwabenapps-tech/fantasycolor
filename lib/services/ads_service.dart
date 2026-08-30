import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

/// Interstitials für Fantasy Color (Kids-Mode / kindgerechte Ads).
///
/// Während des Malens/Puzzles: keine Werbung.
/// Beim Verlassen (Zurück) oder Abschluss: optional ein Interstitial.
/// Fehlt eine Ad oder schlägt sie fehl → App geht einfach weiter.
class AdsService {
  AdsService._();

  static bool _initialized = false;
  static InterstitialAd? _interstitial;
  static bool _loading = false;
  static bool _showing = false;

  static bool get isReady => _initialized;

  /// SDK starten + Kindermodus (COPPA-ähnlich) + erste Ad laden.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          // Kinder-App: kindgerechte Behandlung + nur G-Content.
          ageRestrictedTreatment: AgeRestrictedTreatment.child,
          maxAdContentRating: MaxAdContentRating.g,
        ),
      );
      await MobileAds.instance.initialize();
      _initialized = true;
      await preloadInterstitial();
    } catch (e, st) {
      debugPrint('AdsService.initialize failed: $e\n$st');
      _initialized = false;
    }
  }

  static Future<void> preloadInterstitial() async {
    if (!_initialized || _loading || _interstitial != null) return;
    _loading = true;
    try {
      await InterstitialAd.load(
        adUnitId: AdsConfig.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            _loading = false;
          },
          onAdFailedToLoad: (error) {
            debugPrint('Interstitial failed to load: $error');
            _interstitial = null;
            _loading = false;
          },
        ),
      );
    } catch (e, st) {
      debugPrint('AdsService.preloadInterstitial failed: $e\n$st');
      _loading = false;
    }
  }

  /// Zeigt ein Interstitial, falls geladen — sonst sofort return.
  static Future<void> showInterstitial() async {
    if (!_initialized || _showing) return;

    final ad = _interstitial;
    if (ad == null) {
      unawaited(preloadInterstitial());
      return;
    }

    _interstitial = null;
    _showing = true;
    final done = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        unawaited(preloadInterstitial());
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: $error');
        ad.dispose();
        _showing = false;
        unawaited(preloadInterstitial());
        if (!done.isCompleted) done.complete();
      },
    );

    try {
      await ad.show();
      await done.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {},
      );
    } catch (e, st) {
      debugPrint('AdsService.showInterstitial failed: $e\n$st');
      ad.dispose();
      _showing = false;
      unawaited(preloadInterstitial());
    }
  }
}
