import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pixel_puzzle.dart';

/// Persistierter Pixel-/Malen-nach-Zahlen-Fortschritt inkl. Vorschaubild.
class PixelProgressStore extends ChangeNotifier {
  PixelProgressStore();

  static const _prefsKey = 'pixel_progress_ids';

  final Set<String> _ids = <String>{};
  final Map<String, int> _versions = <String, int>{};
  final Map<String, bool> _completed = <String, bool>{};
  Directory? _dir;
  bool _ready = false;

  bool get isReady => _ready;

  bool hasProgress(String pageId) => _ids.contains(pageId);

  bool isCompleted(String pageId) => _completed[pageId] ?? false;

  int versionOf(String pageId) => _versions[pageId] ?? 0;

  Future<void> load() async {
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory('${docs.path}/pixel_progress');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? const <String>[];
    _ids
      ..clear()
      ..addAll(stored);

    final existing = <String>{};
    for (final id in _ids) {
      final jsonFile = _jsonFileFor(id);
      final pngFile = _pngFileFor(id);
      if (jsonFile != null &&
          pngFile != null &&
          await jsonFile.exists() &&
          await pngFile.exists()) {
        existing.add(id);
        _versions[id] = 1;
        try {
          final map = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
          _completed[id] = map['completed'] == true;
        } catch (_) {
          _completed[id] = false;
        }
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

  File? previewFileFor(String pageId) {
    if (!_ids.contains(pageId)) return null;
    return _pngFileFor(pageId);
  }

  File? _jsonFileFor(String id) {
    final dir = _dir;
    if (dir == null) return null;
    return File('${dir.path}/${_safe(id)}.json');
  }

  File? _pngFileFor(String id) {
    final dir = _dir;
    if (dir == null) return null;
    return File('${dir.path}/${_safe(id)}.png');
  }

  String _safe(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

  Future<PixelProgressSnapshot?> loadSnapshot(String pageId) async {
    final file = _jsonFileFor(pageId);
    if (file == null || !await file.exists()) return null;
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return PixelProgressSnapshot.fromJson(map);
    } catch (e, st) {
      debugPrint('PixelProgressStore.loadSnapshot failed: $e\n$st');
      return null;
    }
  }

  Future<void> saveSnapshot(
    PixelProgressSnapshot snapshot, {
    required Uint8List previewPng,
  }) async {
    final jsonFile = _jsonFileFor(snapshot.pageId);
    final pngFile = _pngFileFor(snapshot.pageId);
    if (jsonFile == null || pngFile == null) return;

    await jsonFile.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    await pngFile.writeAsBytes(previewPng, flush: true);
    await FileImage(pngFile).evict();

    _ids.add(snapshot.pageId);
    _completed[snapshot.pageId] = snapshot.completed;
    _versions[snapshot.pageId] = (_versions[snapshot.pageId] ?? 0) + 1;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _ids.toList(growable: false));
  }

  Future<void> clearProgress(String pageId) async {
    final jsonFile = _jsonFileFor(pageId);
    final pngFile = _pngFileFor(pageId);
    if (jsonFile != null && await jsonFile.exists()) await jsonFile.delete();
    if (pngFile != null && await pngFile.exists()) {
      await FileImage(pngFile).evict();
      await pngFile.delete();
    }
    _ids.remove(pageId);
    _versions.remove(pageId);
    _completed.remove(pageId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _ids.toList(growable: false));
  }
}

class PixelProgressSnapshot {
  const PixelProgressSnapshot({
    required this.pageId,
    required this.difficulty,
    required this.cols,
    required this.rows,
    required this.cells,
    required this.paletteArgb,
    required this.filled,
    required this.selectedNumber,
    required this.completed,
  });

  final String pageId;
  final PixelDifficulty difficulty;
  final int cols;
  final int rows;
  final List<int> cells;
  final List<int> paletteArgb;
  final List<bool> filled;
  final int selectedNumber;
  final bool completed;

  int get filledCount => filled.where((f) => f).length;

  PixelPuzzle toPuzzle() {
    return PixelPuzzle(
      cols: cols,
      rows: rows,
      cells: cells,
      palette: [
        for (var i = 0; i < paletteArgb.length; i++)
          PixelPaletteColor(
            number: i + 1,
            color: Color(paletteArgb[i]),
          ),
      ],
      difficulty: difficulty,
    );
  }

  Map<String, dynamic> toJson() => {
        'pageId': pageId,
        'difficulty': difficulty.name,
        'cols': cols,
        'rows': rows,
        'cells': cells,
        'paletteArgb': paletteArgb,
        'filled': [for (final f in filled) f ? 1 : 0],
        'selectedNumber': selectedNumber,
        'completed': completed,
      };

  factory PixelProgressSnapshot.fromJson(Map<String, dynamic> json) {
    final filledRaw = (json['filled'] as List<dynamic>? ?? const [])
        .map((e) => e == 1 || e == true)
        .toList(growable: false);
    final difficultyName = json['difficulty'] as String? ?? 'standard';
    final difficulty = PixelDifficulty.fromStorageName(difficultyName);
    return PixelProgressSnapshot(
      pageId: json['pageId'] as String? ?? '',
      difficulty: difficulty,
      cols: json['cols'] as int? ?? 1,
      rows: json['rows'] as int? ?? 1,
      cells: (json['cells'] as List<dynamic>? ?? const [])
          .map((e) => e as int)
          .toList(growable: false),
      paletteArgb: (json['paletteArgb'] as List<dynamic>? ?? const [])
          .map((e) => e as int)
          .toList(growable: false),
      filled: filledRaw,
      selectedNumber: json['selectedNumber'] as int? ?? 1,
      completed: json['completed'] == true,
    );
  }

  factory PixelProgressSnapshot.fromPuzzle({
    required String pageId,
    required PixelPuzzle puzzle,
    required List<bool> filled,
    required int selectedNumber,
    required bool completed,
  }) {
    return PixelProgressSnapshot(
      pageId: pageId,
      difficulty: puzzle.difficulty,
      cols: puzzle.cols,
      rows: puzzle.rows,
      cells: List<int>.from(puzzle.cells),
      paletteArgb: [
        for (final p in puzzle.palette) p.color.toARGB32(),
      ],
      filled: List<bool>.from(filled),
      selectedNumber: selectedNumber,
      completed: completed,
    );
  }
}
