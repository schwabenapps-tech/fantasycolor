import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platzierte Stickers auf einem Ausmalbild (normierte 0–1 Koordinaten).
class PlacedSticker {
  const PlacedSticker({
    required this.stickerId,
    required this.x,
    required this.y,
    this.scale = 0.22,
    this.rotation = 0,
  });

  final String stickerId;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  Map<String, dynamic> toJson() => {
        'stickerId': stickerId,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
      };

  factory PlacedSticker.fromJson(Map<String, dynamic> json) {
    return PlacedSticker(
      stickerId: json['stickerId']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.5,
      scale: (json['scale'] as num?)?.toDouble() ?? 0.22,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    );
  }

  PlacedSticker copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return PlacedSticker(
      stickerId: stickerId,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}

sealed class _StickerUndoAction {
  const _StickerUndoAction();
}

class _AddUndo extends _StickerUndoAction {
  const _AddUndo(this.index);
  final int index;
}

class _RemoveUndo extends _StickerUndoAction {
  const _RemoveUndo(this.index, this.sticker);
  final int index;
  final PlacedSticker sticker;
}

class ColoringStickerPlacementsStore extends ChangeNotifier {
  ColoringStickerPlacementsStore();

  static const _keyPrefix = 'coloring_sticker_placements_v1_';

  final Map<String, List<PlacedSticker>> _byPage = {};
  final Map<String, List<_StickerUndoAction>> _undoByPage = {};
  final Map<String, DateTime> _lastChangeAt = {};

  List<PlacedSticker> forPage(String pageId) =>
      List.unmodifiable(_byPage[pageId] ?? const []);

  bool canUndo(String pageId) => (_undoByPage[pageId]?.isNotEmpty ?? false);

  DateTime lastChangeAt(String pageId) =>
      _lastChangeAt[pageId] ?? DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> loadPage(String pageId) async {
    if (_byPage.containsKey(pageId)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$pageId');
      if (raw == null || raw.isEmpty) {
        _byPage[pageId] = [];
        return;
      }
      final list = jsonDecode(raw) as List<dynamic>;
      _byPage[pageId] = [
        for (final item in list)
          if (item is Map)
            PlacedSticker.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (e, st) {
      debugPrint('ColoringStickerPlacementsStore.load failed: $e\n$st');
      _byPage[pageId] = [];
    }
    notifyListeners();
  }

  Future<void> setPlacements(
    String pageId,
    List<PlacedSticker> items, {
    bool recordUndo = false,
  }) async {
    _byPage[pageId] = List.of(items);
    if (recordUndo) {
      _lastChangeAt[pageId] = DateTime.now();
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_keyPrefix$pageId',
        jsonEncode([for (final p in items) p.toJson()]),
      );
    } catch (e, st) {
      debugPrint('ColoringStickerPlacementsStore.save failed: $e\n$st');
    }
  }

  void _pushUndo(String pageId, _StickerUndoAction action) {
    final stack = _undoByPage.putIfAbsent(pageId, () => <_StickerUndoAction>[]);
    stack.add(action);
    if (stack.length > 40) stack.removeAt(0);
    _lastChangeAt[pageId] = DateTime.now();
  }

  Future<void> add(String pageId, PlacedSticker sticker) async {
    await loadPage(pageId);
    final next = [...forPage(pageId), sticker];
    _pushUndo(pageId, _AddUndo(next.length - 1));
    await setPlacements(pageId, next, recordUndo: true);
  }

  Future<void> updateAt(String pageId, int index, PlacedSticker sticker) async {
    await loadPage(pageId);
    final next = [...forPage(pageId)];
    if (index < 0 || index >= next.length) return;
    next[index] = sticker;
    await setPlacements(pageId, next);
  }

  Future<void> removeAt(String pageId, int index) async {
    await loadPage(pageId);
    final next = [...forPage(pageId)];
    if (index < 0 || index >= next.length) return;
    final removed = next.removeAt(index);
    _pushUndo(pageId, _RemoveUndo(index, removed));
    await setPlacements(pageId, next, recordUndo: true);
  }

  Future<void> undo(String pageId) async {
    final stack = _undoByPage[pageId];
    if (stack == null || stack.isEmpty) return;
    await loadPage(pageId);
    final action = stack.removeLast();
    final next = [...forPage(pageId)];
    switch (action) {
      case _AddUndo(:final index):
        if (index >= 0 && index < next.length) {
          next.removeAt(index);
        } else if (next.isNotEmpty) {
          next.removeLast();
        }
      case _RemoveUndo(:final index, :final sticker):
        final insertAt = index.clamp(0, next.length);
        next.insert(insertAt, sticker);
    }
    _lastChangeAt[pageId] = DateTime.now();
    await setPlacements(pageId, next);
  }
}
