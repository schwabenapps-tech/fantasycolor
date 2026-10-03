/// Store-IDs / Links für Fairy Fantasy Color.
class StoreConfig {
  StoreConfig._();

  /// App Store Connect → App-Informationen → Apple-ID.
  static const String appleAppId = '6818653787';

  static const String androidPackageId = 'com.schwabenapps.mkz.fantasyColor';

  /// App-Store-Produktseite (US; Store leitet regional um).
  static Uri get appStoreUri => Uri.parse(
        'https://apps.apple.com/app/id$appleAppId',
      );

  /// Play-Store-Seite (gültig sobald die App gelistet ist).
  static Uri get playStoreUri => Uri.parse(
        'https://play.google.com/store/apps/details?id=$androidPackageId',
      );

  /// itms-apps für „Rate“ auf dem Gerät.
  static Uri get appStoreReviewUri => Uri.parse(
        'itms-apps://itunes.apple.com/app/id$appleAppId?action=write-review',
      );
}
