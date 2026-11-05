import 'dart:io';
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';

/// Anonyme Installations-ID — nur lokal, kein Login.
///
/// Gespeichert als Datei unter Application Support (Android: `files/`),
/// von Auto-Backup ausgeschlossen. Bei Deinstallation weg. Keine Server-Liste.
class DeviceIdService {
  DeviceIdService._();

  static final DeviceIdService instance = DeviceIdService._();

  /// Legacy-Key (Migration); neue Installs nutzen nur die Datei.
  static const prefsKey = 'device_install_id_v1';
  static const fileName = 'device_install_id_v1.txt';

  String? _id;

  /// Leer bis [ensureInitialized] gelaufen ist.
  String get id => _id ?? '';

  bool get isReady => _id != null && _id!.isNotEmpty;

  Future<String> ensureInitialized({bool bindFirebase = true}) async {
    if (_id != null && _id!.isNotEmpty) {
      if (bindFirebase) await _bindFirebase(_id!);
      return _id!;
    }

    var stored = await _readFromFile();
    if (stored.isEmpty) {
      // Migration von früherer SharedPreferences-Speicherung.
      final prefs = await SharedPreferences.getInstance();
      stored = prefs.getString(prefsKey)?.trim() ?? '';
      if (stored.isNotEmpty) {
        if (await _persist(stored)) {
          await prefs.remove(prefsKey);
        }
      }
    }
    if (stored.isEmpty) {
      stored = _generateUuidV4();
      final ok = await _persist(stored);
      if (!ok) {
        // Letzter Fallback: Prefs (kann Backup unterliegen, besser als
        // nur In-Memory-ID die beim Neustart wechselt).
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(prefsKey, stored);
        } catch (e, st) {
          debugPrint('DeviceIdService prefs fallback failed: $e\n$st');
        }
      }
    }
    _id = stored;

    if (bindFirebase) {
      await _bindFirebase(stored);
    }
    return stored;
  }

  Future<File> _idFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<String> _readFromFile() async {
    try {
      final file = await _idFile();
      if (!await file.exists()) return '';
      return (await file.readAsString()).trim();
    } catch (e, st) {
      debugPrint('DeviceIdService read failed: $e\n$st');
      return '';
    }
  }

  /// Schreibt die ID und prüft per Read-Back — bei Fehler `false`.
  Future<bool> _persist(String id) async {
    try {
      final file = await _idFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(id, flush: true);
      final roundtrip = (await file.readAsString()).trim();
      return roundtrip == id;
    } catch (e, st) {
      debugPrint('DeviceIdService write failed: $e\n$st');
      return false;
    }
  }

  Future<void> _bindFirebase(String id) async {
    try {
      await FirebaseAnalytics.instance.setUserId(id: id);
    } catch (e, st) {
      debugPrint('DeviceIdService Analytics setUserId failed: $e\n$st');
    }
    try {
      final crash = FirebaseCrashlytics.instance;
      await crash.setUserIdentifier(id);
      await crash.setCustomKey('device_id', id);
      await crash.setCustomKey('app_version', AppVersion.name);
    } catch (e, st) {
      debugPrint('DeviceIdService Crashlytics bind failed: $e\n$st');
    }
  }

  static String _generateUuidV4() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-'
        '${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-'
        '${h.substring(20)}';
  }
}
