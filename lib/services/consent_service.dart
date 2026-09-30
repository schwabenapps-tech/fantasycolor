import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google UMP (User Messaging Platform) — DSGVO/EEA Consent vor Ads.
///
/// Fantasy Color ist eine Kinder-/Familien-App:
/// - [tagForUnderAgeOfConsent] = true → UMP zeigt Kindern kein Consent-Formular
/// - Ads bleiben child-directed + non-personalized ([AdsService])
///
/// In AdMob trotzdem eine **European regulations / GDPR**-Message anlegen und
/// der App zuweisen — sonst liefert UMP in der EU oft keine Formulare.
class ConsentService extends ChangeNotifier {
  ConsentService._();

  static final ConsentService instance = ConsentService._();

  bool _gathered = false;
  bool _canRequestAds = false;
  PrivacyOptionsRequirementStatus _privacyOptionsStatus =
      PrivacyOptionsRequirementStatus.unknown;

  /// Läuft höchstens einmal parallel — weitere Aufrufe warten mit.
  Future<void>? _inFlight;

  bool get gathered => _gathered;
  bool get canRequestAds => _canRequestAds;
  bool get privacyOptionsRequired =>
      _privacyOptionsStatus == PrivacyOptionsRequirementStatus.required;

  /// Consent-Info aktualisieren + ggf. Formular zeigen (jedes App-Start).
  Future<void> gatherConsent() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _gatherConsentOnce();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<void> _gatherConsentOnce() async {
    final done = Completer<void>();

    final params = ConsentRequestParameters(
      // Kids: Consent nicht von Kindern einholen.
      tagForUnderAgeOfConsent: true,
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((error) {
            if (error != null) {
              debugPrint(
                'ConsentService form error: ${error.errorCode} ${error.message}',
              );
            }
          });
        } catch (e, st) {
          debugPrint('ConsentService.loadAndShow failed: $e\n$st');
        }
        await _refreshStatus();
        if (!done.isCompleted) done.complete();
      },
      (FormError error) async {
        debugPrint(
          'ConsentService.update failed: ${error.errorCode} ${error.message}',
        );
        // Netzwerk/Cache-Fehler: App nicht dauerhaft ohne Ads lassen.
        await _refreshStatus(forceAllowAds: true);
        if (!done.isCompleted) done.complete();
      },
    );

    try {
      await done.future.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      debugPrint('ConsentService.gatherConsent timed out — allowing ads');
      // Sonst: Timeout → canRequestAds noch false → AdsService skippt für immer,
      // während der späte UMP-Callback Ads nicht mehr startet.
      await _refreshStatus(forceAllowAds: true);
    }
  }

  Future<void> _refreshStatus({bool forceAllowAds = false}) async {
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      _privacyOptionsStatus =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    } catch (e, st) {
      debugPrint('ConsentService._refreshStatus failed: $e\n$st');
      if (forceAllowAds) _canRequestAds = true;
    }
    // Timeout/Fehler: auch wenn die API bewusst false liefert, nicht blockieren
    // (Kinder-App mit TFUA — Formular wird ohnehin nicht von Kindern verlangt).
    if (forceAllowAds && !_canRequestAds) {
      _canRequestAds = true;
    }
    _gathered = true;
    notifyListeners();
  }

  /// Privacy-Options-Formular (Widerruf / Änderung) — wenn von UMP verlangt.
  Future<FormError?> showPrivacyOptions() async {
    FormError? formError;
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        formError = error;
      });
    } catch (e, st) {
      debugPrint('ConsentService.showPrivacyOptions failed: $e\n$st');
    }
    await _refreshStatus();
    return formError;
  }
}
