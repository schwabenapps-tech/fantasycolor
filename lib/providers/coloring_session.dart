import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../data/paint_catalog.dart';
import '../painting/coloring_bitmap.dart';
import '../widgets/freehand_stroke_painter.dart';

/// Stiftstärke für kindgerechte Auswahl.
enum PenSize { thin, medium, thick }

/// Ein freier Stift- oder Radierer-Strich (Overlay).
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
    _category = PaintCatalog.categories.first;
    final swatches = PaintCatalog.swatchesFor(_category!);
    _swatch = swatches.isEmpty ? null : swatches.first;
  }

  PaintCategory? _category;
  PaintTool _tool = PaintTool.brush;
  PaintTool _lastDrawTool = PaintTool.brush;
  PaintSwatch? _swatch;
  PenSize _penSize = PenSize.medium;
  ColoringBitmap? _bitmap;
  final List<FreehandStroke> _strokes = <FreehandStroke>[];
  final List<ColoringAction> _undoStack = <ColoringAction>[];
  int _generation = 0;
  Size? sheetSize;
  bool _dirty = false;

  PaintCategory? get category => _category;
  PaintTool get tool => _tool;
  PaintTool get lastDrawTool => _lastDrawTool;
  PaintSwatch? get swatch => _swatch;
  PenSize get penSize => _penSize;
  ColoringBitmap? get bitmap => _bitmap;
  List<FreehandStroke> get strokes => _strokes;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canReset => _dirty || _undoStack.isNotEmpty || _strokes.isNotEmpty;
  bool get hasCategory => _category != null;
  int get generation => _generation;

  bool get eraserClearsFills =>
      _tool == PaintTool.eraser && _lastDrawTool == PaintTool.brush;

  List<PaintSwatch> get availableSwatches =>
      _category == null ? const [] : PaintCatalog.swatchesFor(_category!);

  void attachBitmap(ColoringBitmap bitmap, {bool notify = true}) {
    _bitmap = bitmap;
    _strokes.clear();
    _undoStack.clear();
    _generation++;
    if (notify) {
      notifyListeners();
    }
  }

  void markLoadedProgress() {
    _dirty = true;
  }

  void selectCategory(PaintCategory category) {
    _category = category;
    final swatches = PaintCatalog.swatchesFor(category);
    _swatch = swatches.isEmpty ? null : swatches.first;
    if (_tool == PaintTool.eraser) {
      _tool = PaintTool.brush;
    }
    notifyListeners();
  }

  void clearCategory() {
    _category = null;
    _swatch = null;
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

  /// Stiftstärke in Zeichenkoordinaten.
  double penStrokeSize() {
    return switch (_penSize) {
      PenSize.thin => 9,
      PenSize.medium => 16,
      PenSize.thick => 28,
    };
  }

  PathFillStyle? currentFillStyle() {
    final selected = _swatch;
    final cat = _category;
    if (selected == null || cat == null) return null;
    return PathFillStyle(color: selected.color, category: cat);
  }

  /// Flood-Fill / Flächen-Radierer auf dem Bitmap.
  bool applyFillAt(Offset imagePoint) {
    final bitmap = _bitmap;
    if (bitmap == null) return false;

    final erase = _tool == PaintTool.eraser;
    if (!erase && currentFillStyle() == null) return false;
    if (erase && !eraserClearsFills) return false;

    final style = currentFillStyle();
    final before = bitmap.snapshot();
    final changed = bitmap.floodFill(
      imagePoint.dx.round(),
      imagePoint.dy.round(),
      color: style?.color ?? const Color(0xFFFFFFFF),
      category: style?.category ?? PaintCategory.solid,
      erase: erase,
    );
    if (changed <= 0) return false;

    _undoStack.add(BitmapSnapshotAction(before));
    if (_undoStack.length > 25) {
      _undoStack.removeAt(0);
    }
    _dirty = true;
    _generation++;
    notifyListeners();
    return true;
  }

  void commitStroke(FreehandStroke stroke) {
    _strokes.add(stroke);
    _undoStack.add(AddStrokeAction(stroke));
    if (_undoStack.length > 25) {
      _undoStack.removeAt(0);
    }
    _dirty = true;
    _generation++;
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    switch (action) {
      case BitmapSnapshotAction(:final before):
        _bitmap?.restoreSnapshot(before);
      case AddStrokeAction(:final stroke):
        _strokes.remove(stroke);
    }
    _generation++;
    notifyListeners();
  }

  /// Alle Farben und Striche zurücksetzen (Bild wie neu).
  void resetAll() {
    _bitmap?.resetToOriginal();
    _strokes.clear();
    _undoStack.clear();
    _dirty = false;
    _generation++;
    notifyListeners();
  }

  /// Ausgemaltes Bild inkl. Stift-Striche als PNG exportieren.
  Future<Uint8List?> exportColoredPng() async {
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
        generation: _generation,
      ).paint(canvas, sheet);
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final composed = await picture.toImage(bitmap.width, bitmap.height);
    final bytes = await composed.toByteData(format: ui.ImageByteFormat.png);
    base.dispose();
    composed.dispose();

    final png = bytes?.buffer.asUint8List();
    if (png != null) {
      bitmap.applyWorkingPng(png);
      _strokes.clear();
      _undoStack.clear();
      _generation++;
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
      case PaintCategory.watercolor:
        return color.withValues(alpha: 0.55);
      case PaintCategory.solid:
      case PaintCategory.glow:
      case PaintCategory.glitter:
        return color;
    }
  }
}
