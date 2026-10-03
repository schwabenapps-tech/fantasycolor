import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Custom-URL-Scheme: `fantasycolor://…` (z. B. App-Store In-App-Events).
///
/// Öffnet die App und signalisiert Navigation zum Haupt-Hub
/// (dort ist das Event sichtbar).
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  static const scheme = 'fantasycolor';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Cold-Start: Link war beim Start da → Hub nach StartScreen öffnen.
  bool pendingOpenHub = false;

  /// Warm-Start: App läuft schon → sofort navigieren.
  VoidCallback? onOpenHub;

  Future<void> initialize() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (_shouldOpenHub(initial)) {
        pendingOpenHub = true;
        debugPrint('DeepLinkService: initial link $initial');
      }
    } catch (e, st) {
      debugPrint('DeepLinkService.getInitialLink failed: $e\n$st');
    }

    await _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (!_shouldOpenHub(uri)) return;
        debugPrint('DeepLinkService: link $uri');
        pendingOpenHub = true;
        onOpenHub?.call();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('DeepLinkService.stream error: $e\n$st');
      },
    );
  }

  bool consumePendingOpenHub() {
    if (!pendingOpenHub) return false;
    pendingOpenHub = false;
    return true;
  }

  bool _shouldOpenHub(Uri? uri) {
    if (uri == null) return false;
    return uri.scheme.toLowerCase() == scheme;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
