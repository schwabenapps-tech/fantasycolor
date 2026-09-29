import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

/// Interstitials für Fantasy Color (Kids-Mode / kindgerechte Ads).
///
/// Während des Malens/Puzzles: **keine** Werbung.
///
/// Timing:
/// - Ausmalen/Pixel verlassen (ohne Feier): jedes **3.** Mal
/// - Nach Ausmalen-/Pixel-Feier (Fertig / Als Puzzle): jedes **2.** Mal
/// - Puzzle gelöst (beim Schließen der Feier): jedes **2.** Mal
/// - Pixel-Modus freischalten: **einmalig**
///
/// Fehlt eine Ad oder schlägt sie fehl → App geht einfach weiter.
class AdsService {
  AdsService._();

  static bool _initialized = false;
  static InterstitialAd? _interstitial;
  static bool _loading = false;
  static bool _showing = false;

  static int _coloringLeaveCount = 0;
  static int _coloringFinishCount = 0;
  static int _puzzleFinishCount = 0;

  static bool get isReady => _initialized;

  /// Non-personalized + child-safe request extras (Designed for Families).
  static const AdRequest _kidsAdRequest = AdRequest(
    extras: <String, String>{'npa': '1'},
  );

  /// SDK starten + Kindermodus (COPPA / child-directed) + erste Ad laden.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          // Kinder-App: kindgerechte Behandlung + nur G-Content.
          ageRestrictedTreatment: AgeRestrictedTreatment.child,
          maxAdContentRating: MaxAdContentRating.g,
          // Zusätzlich explizit (ältere/native Pfade): Child-directed + under-age.
          // ignore: deprecated_member_use
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
          // ignore: deprecated_member_use
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
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
        request: _kidsAdRequest,
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

  /// Ausmalen/Pixel ohne Fertig-Feier verlassen: jedes 3. Mal.
  static Future<void> showColoringLeaveInterstitial() async {
    _coloringLeaveCount++;
    if (_coloringLeaveCount % 3 != 0) {
      unawaited(preloadInterstitial());
      return;
    }
    await showInterstitial();
  }

  /// Nach der Ausmalen-/Pixel-Feier („Fertig“ / „Als Puzzle“): jedes 2. Mal.
  static Future<void> showColoringFinishChoiceInterstitial() async {
    _coloringFinishCount++;
    if (_coloringFinishCount % 2 != 0) {
      unawaited(preloadInterstitial());
      return;
    }
    await showInterstitial();
  }

  /// Puzzle gelöst: jedes 2. Mal.
  static Future<void> showPuzzleFinishInterstitial() async {
    _puzzleFinishCount++;
    if (_puzzleFinishCount % 2 != 0) {
      unawaited(preloadInterstitial());
      return;
    }
    await showInterstitial();
  }

  /// @Deprecated — bitte spezifische Methoden nutzen.
  static Future<void> showExitInterstitial() => showColoringLeaveInterstitial();

  /// Zeigt ein Interstitial, falls geladen — sonst sofort return.
  /// Für Freischaltungen o.Ä., die immer Werbung brauchen.
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
