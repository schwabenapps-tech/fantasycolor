import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Speichert ausgemalte Bilder und zeigt den Fortschritt in der Galerie.
class ColoringProgressStore extends ChangeNotifier {
  ColoringProgressStore();

  static const _prefsKey = 'colored_page_ids';
  static const _hashesPrefsKey = 'colored_page_asset_hashes';
  static const _invalidateAppliedKey = 'coloring_invalidate_applied';

  final Set<String> _ids = <String>{};
  final Map<String, int> _versions = <String, int>{};
  final Map<String, String> _assetHashes = <String, String>{};
  Directory? _dir;
  bool _ready = false;

  bool get isReady => _ready;

  bool hasProgress(String id) => _ids.contains(id);

  int versionOf(String id) => _versions[id] ?? 0;

  Future<void> load() async {
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory('${docs.path}/coloring_progress');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? const <String>[];
    _ids
      ..clear()
      ..addAll(stored);

    _assetHashes
      ..clear()
      ..addAll(_decodeHashMap(prefs.getString(_hashesPrefsKey)));

    // Verwaiste Prefs entfernen, fehlende Dateien bereinigen.
    final existing = <String>{};
    for (final id in _ids) {
      final file = _fileFor(id);
      if (file != null && await file.exists()) {
        existing.add(id);
        _versions[id] = 1;
      } else {
        _assetHashes.remove(id);
      }
    }
    if (existing.length != _ids.length) {
      _ids
        ..clear()
        ..addAll(existing);
      await _persistIds(prefs);
      await _persistHashes(prefs);
    }

    await _invalidateStaleProgress(prefs);

    _ready = true;
    notifyListeners();
  }

  /// Löscht Fortschritt nur für ausgetauschte Motive (+ Hash-Mismatch).
  Future<void> _invalidateStaleProgress(SharedPreferences prefs) async {
    final currentHashes = await _loadCurrentAssetHashes();
    final toClear = <String>{};

    // Explizite Liste aus dem Sync-Skript (nur geänderte IDs).
    try {
      final raw = await rootBundle.loadString(
        'assets/coloring_invalidate_ids.json',
      );
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => e.toString())
          .toList(growable: false);
      final fingerprint = list.join('|');
      if (list.isNotEmpty &&
          prefs.getString(_invalidateAppliedKey) != fingerprint) {
        toClear.addAll(list);
        await prefs.setString(_invalidateAppliedKey, fingerprint);
      }
    } catch (_) {
      // Datei optional.
    }

    // Hash fehlt (älterer Stand) oder weicht ab → Fortschritt verwerfen.
    if (currentHashes.isNotEmpty) {
      for (final id in _ids.toList(growable: false)) {
        final current = currentHashes[id];
        if (current == null) continue;
        final stored = _assetHashes[id];
        if (stored == null || stored != current) {
          toClear.add(id);
        }
      }
    }

    for (final id in toClear) {
      await clearProgress(id);
    }
  }

  Future<Map<String, String>> _loadCurrentAssetHashes() async {
    try {
      final raw =
          await rootBundle.loadString('assets/coloring_asset_hashes.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) e.key: e.value.toString(),
      };
    } catch (_) {
      return const {};
    }
  }

  File? fileFor(String id) {
    final file = _fileFor(id);
    if (file == null || !_ids.contains(id)) return null;
    return file;
  }

  File? _fileFor(String id) {
    final dir = _dir;
    if (dir == null) return null;
    final safe = id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}/$safe.png');
  }

  Future<void> saveProgress(String id, Uint8List pngBytes) async {
    final file = _fileFor(id);
    if (file == null) return;
    await file.writeAsBytes(pngBytes, flush: true);
    // Gleicher Pfad → Flutter-ImageCache sonst mit altem Thumbnail.
    await FileImage(file).evict();
    _ids.add(id);
    _versions[id] = (_versions[id] ?? 0) + 1;

    final hashes = await _loadCurrentAssetHashes();
    final hash = hashes[id];
    if (hash != null) {
      _assetHashes[id] = hash;
    }

    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _persistIds(prefs);
    await _persistHashes(prefs);
  }

  Future<Uint8List?> loadProgressBytes(String id) async {
    final file = fileFor(id);
    if (file == null || !await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> clearProgress(String id) async {
    final file = _fileFor(id);
    if (file != null && await file.exists()) {
      final image = FileImage(file);
      await image.evict();
      await file.delete();
    }
    _ids.remove(id);
    _versions.remove(id);
    _assetHashes.remove(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _persistIds(prefs);
    await _persistHashes(prefs);
  }

  /// Alle gespeicherten Ausmal-Fortschritte löschen.
  Future<void> clearAllProgress() async {
    final dir = _dir;
    if (dir != null && await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File) {
          await FileImage(entity).evict();
          await entity.delete();
        }
      }
    }
    _ids.clear();
    _versions.clear();
    _assetHashes.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, const <String>[]);
    await prefs.remove(_hashesPrefsKey);
  }

  Future<void> _persistIds(SharedPreferences prefs) async {
    await prefs.setStringList(_prefsKey, _ids.toList(growable: false));
  }

  Future<void> _persistHashes(SharedPreferences prefs) async {
    await prefs.setString(_hashesPrefsKey, jsonEncode(_assetHashes));
  }

  Map<String, String> _decodeHashMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) e.key: e.value.toString(),
      };
    } catch (_) {
      return {};
    }
  }
}
