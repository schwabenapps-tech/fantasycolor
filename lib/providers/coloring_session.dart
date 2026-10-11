import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/paint_catalog.dart';
import '../painting/coloring_bitmap.dart';
import '../widgets/freehand_stroke_painter.dart';

/// Penstärke für kindgerechte Auswahl.
enum PenSize { thin, medium, thick }

/// Tray: erst Kategorien, dann Farben (unabhängig von `_category` / Fill-Stil).
enum PaletteTrayMode { categories, colors }

/// Ein freier Pen- oder Eraser-Strich (Overlay).
class FreehandStroke {
  FreehandStroke({
    required this.points,
    required this.color,
    required this.category,
    required this.isEraser,
    required this.size,
  });

  final List<PointVector> points;
  final Color color;
  final PaintCategory category;
  final bool isEraser;
  final double size;
}

sealed class ColoringAction {
  const ColoringAction();
}

class BitmapSnapshotAction extends ColoringAction {
  const BitmapSnapshotAction(this.before);

  final Uint8List before;
}

class AddStrokeAction extends ColoringAction {
  const AddStrokeAction(this.stroke);

  final FreehandStroke stroke;
}

/// Zustand einer Mal-Session für ein PNG-Ausmalbild.
class ColoringSession extends ChangeNotifier {
  ColoringSession() {
    final swatches = PaintCatalog.allSwatches;
    _swatch = swatches.isEmpty ? null : swatches.first;
    _category = _swatch?.category ?? PaintCatalog.categories.first;
    unawaited(loadRecentSwatches());
  }

  static const _recentPrefsKey = 'coloring_recent_swatch_ids_v1';
  static const _maxRecent = 5;
  /// UI-Frame während Drag bündeln (flüssig, wenig Flackern).
  static const _frameBatchMs = 90;

  PaintCategory? _category;
  PaletteTrayMode _trayMode = PaletteTrayMode.categories;
  PaintTool _tool = PaintTool.brush;
  PaintTool _lastDrawTool = PaintTool.brush;
  PaintSwatch? _swatch;
  PenSize _penSize = PenSize.medium;
  ColoringBitmap? _bitmap;
  final List<FreehandStroke> _strokes = <FreehandStroke>[];
  final List<ColoringAction> _undoStack = <ColoringAction>[];
  final List<String> _recentIds = <String>[];
  int _bitmapGeneration = 0;
  int _strokeGeneration = 0;
  Size? sheetSize;
  bool _dirty = false;
  bool _filling = false;

  bool _gestureActive = false;
  final List<Offset> _queuedFillPoints = <Offset>[];
  DateTime? _lastFrameNotifyAt;
  bool _frameDirty = false;
  int _lastNotifiedGen = -1;

  PaintCategory? get category => _category;
  PaletteTrayMode get trayMode => _trayMode;
  PaintTool get tool => _tool;
  PaintTool get lastDrawTool => _lastDrawTool;
  PaintSwatch? get swatch => _swatch;
  PenSize get penSize => _penSize;
  ColoringBitmap? get bitmap => _bitmap;
  List<FreehandStroke> get strokes => _strokes;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canReset => _dirty || _undoStack.isNotEmpty || _strokes.isNotEmpty;
  bool get hasCategory => _category != null;
  bool get showingColors => _trayMode == PaletteTrayMode.colors;

  /// Ändert sich nur bei Bitmap-Fills/Reset — steuert Frame-Rebuild.
  int get bitmapGeneration => _bitmapGeneration;

  /// Ändert sich bei Strichen — steuert Overlay-Repaint ohne Frame-Rebuild.
  int get strokeGeneration => _strokeGeneration;

  /// Kompatibilität: steigt bei jeder sichtbaren Änderung.
  int get generation => _bitmapGeneration + _strokeGeneration;
  bool get isFilling => _filling;
  bool get isFillGestureActive => _gestureActive;

  bool get eraserClearsFills =>
      _tool == PaintTool.eraser && _lastDrawTool == PaintTool.brush;

  List<PaintSwatch> get availableSwatches {
    if (_trayMode != PaletteTrayMode.colors) return const [];
    final cat = _category;
    if (cat == null) return const [];
    return PaintCatalog.swatchesFor(cat);
  }

  /// Zuletzt genutzte Farben (cross-category), für die Farben-Ansicht.
  List<PaintSwatch> get recentSwatches {
    final byId = <String, PaintSwatch>{
      for (final s in PaintCatalog.allSwatches) s.id: s,
    };
    return [
      for (final id in _recentIds) ?byId[id],
    ];
  }

  Future<void> loadRecentSwatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentPrefsKey) ?? const <String>[];
      _recentIds
        ..clear()
        ..addAll(list.take(_maxRecent));
      notifyListeners();
    } catch (e, st) {
      debugPrint('ColoringSession.loadRecentSwatches failed: $e\n$st');
    }
  }

  Future<void> _persistRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentPrefsKey, _recentIds.toList());
    } catch (e, st) {
      debugPrint('ColoringSession._persistRecents failed: $e\n$st');
    }
  }

  void _rememberSwatch(PaintSwatch swatch) {
    _recentIds.remove(swatch.id);
    _recentIds.insert(0, swatch.id);
    while (_recentIds.length > _maxRecent) {
      _recentIds.removeLast();
    }
    unawaited(_persistRecents());
  }

  void attachBitmap(ColoringBitmap bitmap, {bool notify = true}) {
    _bitmap = bitmap;
    _strokes.clear();
    _undoStack.clear();
    _cancelGestureState();
    _bitmapGeneration++;
    _strokeGeneration++;
    if (notify) {
      notifyListeners();
    }
  }

  void markLoadedProgress() {
    _dirty = true;
  }

  double? _cachedCoverage;
  int _cachedCoverageGen = -1;

  /// Ausmal-Anteil 0..1 für Sticker-Fortschritt (Linien ausgeschlossen).
  double paintedCoverageRatio() {
    final bmp = _bitmap;
    if (bmp == null) return 0;
    final gen = generation;
    if (_cachedCoverage != null && _cachedCoverageGen == gen) {
      return _cachedCoverage!;
    }
    // Offene Pen-Striche zählen grob mit (noch nicht eingefroren).
    final base = bmp.paintedCoverageRatio(step: 4);
    final strokeBoost =
        _strokes.isEmpty ? 0.0 : (_strokes.length * 0.01).clamp(0.0, 0.08);
    final value = (base + strokeBoost).clamp(0.0, 1.0);
    _cachedCoverage = value;
    _cachedCoverageGen = gen;
    return value;
  }

  static const stickerUnlockCoverage = 0.70;

  bool get meetsStickerCoverage =>
      paintedCoverageRatio() >= stickerUnlockCoverage;

  void openCategoryTray() {
    _trayMode = PaletteTrayMode.categories;
    notifyListeners();
  }

  void selectCategory(PaintCategory category) {
    _category = category;
    final swatches = PaintCatalog.swatchesFor(category);
    // Nur Default setzen, wenn noch keine Farbe aus dieser Kategorie aktiv.
    if (_swatch == null || _swatch!.category != category) {
      _swatch = swatches.isEmpty ? null : swatches.first;
    }
    _trayMode = PaletteTrayMode.colors;
    if (_tool == PaintTool.eraser) {
      _tool = PaintTool.brush;
    }
    notifyListeners();
  }

  void selectTool(PaintTool tool) {
    _tool = tool;
    if (tool == PaintTool.brush || tool == PaintTool.pen) {
      _lastDrawTool = tool;
    }
    notifyListeners();
  }

  void selectSwatch(PaintSwatch swatch) {
    _swatch = swatch;
    _category = swatch.category;
    _trayMode = PaletteTrayMode.colors;
    if (_tool == PaintTool.eraser) {
      _tool = PaintTool.brush;
    }
    notifyListeners();
  }

  void selectPenSize(PenSize size) {
    _penSize = size;
    if (_tool == PaintTool.eraser) {
      _tool = PaintTool.pen;
    } else if (_tool != PaintTool.pen) {
      _tool = PaintTool.pen;
    }
    notifyListeners();
  }

  /// Penstärke in Zeichenkoordinaten.
  double penStrokeSize() {
    return switch (_penSize) {
      PenSize.thin => 2.5,
      PenSize.medium => 6,
      PenSize.thick => 12,
    };
  }

  PathFillStyle? currentFillStyle() {
    final selected = _swatch;
    if (selected == null) return null;
    return PathFillStyle(
      color: selected.color,
      category: selected.category,
    );
  }

  void beginFillGesture() {
    final bitmap = _bitmap;
    if (bitmap == null) return;
    _gestureActive = true;
    _queuedFillPoints.clear();
    _lastFrameNotifyAt = null;
    _frameDirty = false;
  }

  void endFillGesture() {
    if (!_gestureActive) return;
    _cancelGestureState();
    if (_frameDirty) {
      _bitmapGeneration++;
      _frameDirty = false;
    }
    _lastNotifiedGen = _bitmapGeneration;
    notifyListeners();
  }

  void _cancelGestureState() {
    _gestureActive = false;
    // Queue behalten — sonst gehen Tipps verloren, die noch auf den
    // laufenden Fill warten.
    _lastFrameNotifyAt = null;
  }

  void _enqueueFillPoint(Offset imagePoint) {
    _queuedFillPoints.add(imagePoint);
    while (_queuedFillPoints.length > 24) {
      _queuedFillPoints.removeAt(0);
    }
  }

  void _drainFillQueue() {
    if (_queuedFillPoints.isEmpty) return;
    final next = _queuedFillPoints.removeAt(0);
    unawaited(applyFillAt(next));
  }

  void _pushUndoSnapshot(Uint8List before) {
    _undoStack.add(BitmapSnapshotAction(before));
    if (_undoStack.length > 40) {
      _undoStack.removeAt(0);
    }
  }

  void _bumpFrame({required bool force}) {
    if (force || !_gestureActive) {
      _bitmapGeneration++;
      _frameDirty = false;
      _lastFrameNotifyAt = DateTime.now();
      return;
    }
    _frameDirty = true;
    final last = _lastFrameNotifyAt;
    final now = DateTime.now();
    if (last == null ||
        now.difference(last).inMilliseconds >= _frameBatchMs) {
      _bitmapGeneration++;
      _frameDirty = false;
      _lastFrameNotifyAt = now;
    }
  }

  /// Flood-Fill / Flächen-Eraser auf dem Bitmap (Hintergrund-Isolate).
  Future<bool> applyFillAt(Offset imagePoint) async {
    final bitmap = _bitmap;
    if (bitmap == null) return false;

    if (_filling) {
      // Auch einzelne Tipps queuen — sonst gehen schnelle Tipps verloren.
      _enqueueFillPoint(imagePoint);
      return false;
    }

    final erase = _tool == PaintTool.eraser;
    if (!erase && currentFillStyle() == null) return false;
    if (erase && !eraserClearsFills) return false;

    final style = currentFillStyle();
    final rawX = imagePoint.dx.round();
    final rawY = imagePoint.dy.round();
    final seed = bitmap.resolveFillSeed(rawX, rawY);
    if (seed == null) {
      _drainFillQueue();
      return false;
    }
    final (x, y) = seed;
    if (bitmap.shouldSkipFillAt(
      x,
      y,
      color: style?.color ?? const Color(0xFFFFFFFF),
      category: style?.category ?? PaintCategory.solid,
      erase: erase,
    )) {
      _drainFillQueue();
      return false;
    }

    final singleTap = !_gestureActive;
    // Pro Fläche ein Undo — auch innerhalb eines Drag-Fills.
    final before = bitmap.snapshot();

    _filling = true;
    try {
      final changed = await bitmap.floodFillAsync(
        x,
        y,
        color: style?.color ?? const Color(0xFFFFFFFF),
        category: style?.category ?? PaintCategory.solid,
        erase: erase,
      );
      if (changed <= 0) return false;

      _pushUndoSnapshot(before);

      _dirty = true;
      final genBefore = _bitmapGeneration;
      _bumpFrame(force: singleTap);
      final frameBumped = _bitmapGeneration != genBefore;
      if (!erase && _swatch != null) {
        _rememberSwatch(_swatch!);
      }
      if (singleTap || frameBumped) {
        HapticFeedback.selectionClick();
      }
      return true;
    } finally {
      _filling = false;
      if (!_gestureActive || _bitmapGeneration != _lastNotifiedGen) {
        _lastNotifiedGen = _bitmapGeneration;
        notifyListeners();
      }
      _drainFillQueue();
    }
  }

  void commitStroke(FreehandStroke stroke) {
    _strokes.add(stroke);
    _undoStack.add(AddStrokeAction(stroke));
    if (_undoStack.length > 40) {
      _undoStack.removeAt(0);
    }
    _dirty = true;
    _strokeGeneration++;
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    switch (action) {
      case BitmapSnapshotAction(:final before):
        _bitmap?.restoreSnapshot(before);
        _bitmapGeneration++;
      case AddStrokeAction(:final stroke):
        _strokes.remove(stroke);
        _strokeGeneration++;
    }
    notifyListeners();
  }

  /// Alle Farben und Striche zurücksetzen (Bild wie neu).
  void resetAll() {
    _bitmap?.resetToOriginal();
    _strokes.clear();
    _undoStack.clear();
    _cancelGestureState();
    _dirty = false;
    _bitmapGeneration++;
    _strokeGeneration++;
    notifyListeners();
  }

  /// Rendert das aktuelle Bild inkl. Pen-Striche als PNG (Session bleibt unverändert).
  Future<Uint8List?> renderColoredPng() async {
    final bitmap = _bitmap;
    if (bitmap == null) return null;

    if (_strokes.isEmpty) {
      return bitmap.encodeWorkingPng();
    }

    final sheet = sheetSize;
    final base = await bitmap.toUiImage();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, bitmap.width.toDouble(), bitmap.height.toDouble()),
    );
    canvas.drawImage(base, Offset.zero, Paint());

    if (sheet != null && sheet.width > 0 && sheet.height > 0) {
      canvas.save();
      canvas.scale(bitmap.width / sheet.width, bitmap.height / sheet.height);
      FreehandStrokePainter(
        strokes: List<FreehandStroke>.from(_strokes),
        generation: _strokeGeneration,
      ).paint(canvas, sheet);
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final composed = await picture.toImage(bitmap.width, bitmap.height);
    final bytes = await composed.toByteData(format: ui.ImageByteFormat.png);
    base.dispose();
    composed.dispose();
    return bytes?.buffer.asUint8List();
  }

  /// Ausgemaltes Bild inkl. Pen-Striche als PNG exportieren und in Bitmap übernehmen.
  Future<Uint8List?> exportColoredPng() async {
    final bitmap = _bitmap;
    if (bitmap == null) return null;

    final png = await renderColoredPng();
    if (png != null) {
      bitmap.applyWorkingPng(png);
      _strokes.clear();
      _undoStack.clear();
      _bitmapGeneration++;
      _strokeGeneration++;
      notifyListeners();
    }
    return png;
  }
}

/// Kompatibles Fill-Style für Effekte/UI.
class PathFillStyle {
  const PathFillStyle({
    required this.color,
    required this.category,
  });

  final Color color;
  final PaintCategory category;

  Color get displayColor {
    switch (category) {
      case PaintCategory.pastel:
        return color.withValues(alpha: 0.88);
      case PaintCategory.solid:
        return color;
    }
  }
}
