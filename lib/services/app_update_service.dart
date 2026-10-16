import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../app_version.dart';

/// Prüft beim Start (und Resume), ob die installierte Version noch erlaubt ist.
///
/// Remote-Config: `https://cdn.schwabenapps.com/app_config.json`
///
/// ```json
/// {
///   "min_version": "1.2.0",
///   "message": "Please update Fairy Fantasy Color to continue."
/// }
/// ```
///
/// Akzeptiert auch camelCase (`minVersion` / `updateMessage`) wie im
/// Heartbeat-Projekt — sonst greift Force Update stillschweigend nicht.
///
/// App-Version < min → Force Update (nicht schließbar).
/// Netzwerk/404 → fail-open (App bleibt nutzbar).
class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const configUrl = 'https://cdn.schwabenapps.com/app_config.json';

  static const _defaultMessage =
      'A new version of Fairy Fantasy Color is required.\n'
      'Please update in the store to continue playing.';

  bool _checking = false;
  bool get isChecking => _checking;

  bool _forceRequired = false;
  bool get forceRequired => _forceRequired;

  String _message = _defaultMessage;
  String get message => _message;

  String? _minVersion;
  String? get minVersion => _minVersion;

  String _currentVersion = AppVersion.name;
  String get currentVersion => _currentVersion;

  Future<void> check({bool forceRefresh = false}) async {
    if (_checking && !forceRefresh) return;
    _checking = true;
    try {
      // Immer die echte Store-/Build-Version — hardcodierte Konstanten
      // sind im anderen Projekt schon schiefgegangen.
      try {
        final info = await PackageInfo.fromPlatform();
        if (info.version.trim().isNotEmpty) {
          _currentVersion = info.version.trim();
        }
      } catch (e, st) {
        debugPrint(
          'AppUpdateService: PackageInfo failed, fallback '
          '${AppVersion.name}: $e\n$st',
        );
        _currentVersion = AppVersion.name;
      }

      // Cache-Bust (CDN kann 404/alte Config länger halten).
      final uri = Uri.parse(configUrl).replace(
        queryParameters: {
          't': '${DateTime.now().millisecondsSinceEpoch ~/ 30000}',
        },
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          'AppUpdateService: config HTTP ${response.statusCode} '
          '(Force Update inactive until app_config.json is on CDN)',
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        debugPrint('AppUpdateService: config is not a JSON object');
        return;
      }
      final json = Map<String, dynamic>.from(decoded);

      // snake_case + camelCase (Heartbeat nutzt minVersion).
      final minRaw = _asVersionString(
        json['min_version'] ?? json['minVersion'],
      );
      if (minRaw == null || minRaw.isEmpty) {
        debugPrint('AppUpdateService: no min_version/minVersion in config');
        if (_forceRequired) {
          _forceRequired = false;
          notifyListeners();
        }
        return;
      }

      _minVersion = minRaw;
      final remoteMessage = _asString(
        json['message'] ?? json['updateMessage'],
      );
      _message = (remoteMessage != null && remoteMessage.isNotEmpty)
          ? remoteMessage
          : _defaultMessage;

      final needsForce = compareVersions(_currentVersion, minRaw) < 0;
      debugPrint(
        'AppUpdateService: installed=$_currentVersion min=$minRaw '
        'force=$needsForce',
      );

      if (needsForce != _forceRequired) {
        _forceRequired = needsForce;
        notifyListeners();
      } else if (needsForce) {
        // Message kann sich geändert haben.
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('AppUpdateService.check failed: $e\n$st');
    } finally {
      _checking = false;
    }
  }

  /// Semver-Vergleich (major.minor.patch). Zusätzliche Suffixe werden ignoriert.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    final pa = _parseVersion(a);
    final pb = _parseVersion(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      final c = x.compareTo(y);
      if (c != 0) return c;
    }
    return 0;
  }

  @visibleForTesting
  static String? asVersionStringForTest(dynamic value) =>
      _asVersionString(value);

  static String? _asVersionString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final s = value.trim();
      return s.isEmpty ? null : s;
    }
    if (value is num) return value.toString();
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<int> _parseVersion(String raw) {
    final cleaned = raw.trim().split(RegExp(r'[^0-9.]')).first;
    final parts = cleaned
        .split('.')
        .where((p) => p.isNotEmpty)
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }
}
