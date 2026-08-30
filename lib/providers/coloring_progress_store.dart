import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Speichert ausgemalte Bilder und zeigt den Fortschritt in der Galerie.
class ColoringProgressStore extends ChangeNotifier {
  ColoringProgressStore();

  static const _prefsKey = 'colored_page_ids';

  final Set<String> _ids = <String>{};
  final Map<String, int> _versions = <String, int>{};
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

    // Verwaiste Prefs entfernen, fehlende Dateien bereinigen.
    final existing = <String>{};
    for (final id in _ids) {
      final file = _fileFor(id);
      if (file != null && await file.exists()) {
        existing.add(id);
        _versions[id] = 1;
      }
    }
    if (existing.length != _ids.length) {
      _ids
        ..clear()
        ..addAll(existing);
      await prefs.setStringList(_prefsKey, _ids.toList(growable: false));
    }

    _ready = true;
    notifyListeners();
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
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _ids.toList(growable: false));
  }

  Future<Uint8List?> loadProgressBytes(String id) async {
    final file = fileFor(id);
    if (file == null || !await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> clearProgress(String id) async {
    final file = _fileFor(id);
    if (file != null && await file.exists()) {
      await file.delete();
    }
    _ids.remove(id);
    _versions.remove(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _ids.toList(growable: false));
  }
}
