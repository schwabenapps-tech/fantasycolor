import 'dart:math' as math;
import 'dart:ui';

import '../models/puzzle_settings.dart';

/// Orientierung einer Puzzle-Kante: Zahn nach außen, Bucht nach innen, oder flach.
enum JigsawEdge { flat, tab, blank }

/// Erzeugt Puzzle-Pfade für ein Raster (Klassisch / Viereck / Rund / Wellen).
class JigsawLayout {
  JigsawLayout({
    required this.columns,
    required this.rows,
    this.style = PuzzlePieceStyle.jigsaw,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    _buildEdges();
  }

  final int columns;
  final int rows;
  final PuzzlePieceStyle style;
  final math.Random _random;

  /// Horizontale Kanten zwischen Reihen: true = Ausbuchtung nach unten.
  late final List<List<bool>> _horizontalOut;

  /// Vertikale Kanten zwischen Spalten: true = Ausbuchtung nach rechts.
  late final List<List<bool>> _verticalOut;

  int get pieceCount => columns * rows;

  bool get _useTabs => style == PuzzlePieceStyle.jigsaw;
  bool get _useWaves => style == PuzzlePieceStyle.wave;

  void _buildEdges() {
    if (!_useTabs && !_useWaves) {
      _horizontalOut = const [];
      _verticalOut = const [];
      return;
    }
    _horizontalOut = List.generate(
      math.max(0, rows - 1),
      (_) => List.generate(columns, (_) => _random.nextBool()),
    );
    _verticalOut = List.generate(
      rows,
      (_) => List.generate(math.max(0, columns - 1), (_) => _random.nextBool()),
    );
  }

  JigsawEdge topEdge(int col, int row) {
    if (!_useTabs || row == 0) return JigsawEdge.flat;
    // Kante über diesem Teil: true = Ausbuchtung nach unten → hier Bucht.
    return _horizontalOut[row - 1][col] ? JigsawEdge.blank : JigsawEdge.tab;
  }

  JigsawEdge bottomEdge(int col, int row) {
    if (!_useTabs || row == rows - 1) return JigsawEdge.flat;
    return _horizontalOut[row][col] ? JigsawEdge.tab : JigsawEdge.blank;
  }

  JigsawEdge leftEdge(int col, int row) {
    if (!_useTabs || col == 0) return JigsawEdge.flat;
    return _verticalOut[row][col - 1] ? JigsawEdge.blank : JigsawEdge.tab;
  }

  JigsawEdge rightEdge(int col, int row) {
    if (!_useTabs || col == columns - 1) return JigsawEdge.flat;
    return _verticalOut[row][col] ? JigsawEdge.tab : JigsawEdge.blank;
  }

  /// Bounding-Box eines Teils inkl. herausstehender Zapfen/Wellen.
  Rect pieceBounds({
    required int col,
    required int row,
    required Size boardSize,
    double tabSize = 0.24,
  }) {
    final cellW = boardSize.width / columns;
    final cellH = boardSize.height / rows;
    var left = col * cellW;
    var top = row * cellH;
    var right = left + cellW;
    var bottom = top + cellH;

    if (_useTabs) {
      final tabW = cellW * tabSize;
      final tabH = cellH * tabSize;
      if (leftEdge(col, row) == JigsawEdge.tab) left -= tabW;
      if (rightEdge(col, row) == JigsawEdge.tab) right += tabW;
      if (topEdge(col, row) == JigsawEdge.tab) top -= tabH;
      if (bottomEdge(col, row) == JigsawEdge.tab) bottom += tabH;
    } else if (_useWaves) {
      final ampW = cellW * 0.09;
      final ampH = cellH * 0.09;
      left -= ampW;
      right += ampW;
      top -= ampH;
      bottom += ampH;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Pfad für ein Teil in Board-Koordinaten.
  Path piecePath({
    required int col,
    required int row,
    required Size boardSize,
    double tabSize = 0.24,
  }) {
    final cellW = boardSize.width / columns;
    final cellH = boardSize.height / rows;
    final cell = Rect.fromLTWH(col * cellW, row * cellH, cellW, cellH);

    switch (style) {
      case PuzzlePieceStyle.square:
        return Path()..addRect(cell);
      case PuzzlePieceStyle.rounded:
        final r = math.min(cellW, cellH) * 0.18;
        return Path()
          ..addRRect(RRect.fromRectAndRadius(cell, Radius.circular(r)));
      case PuzzlePieceStyle.wave:
        return _wavePath(cell, col: col, row: row);
      case PuzzlePieceStyle.jigsaw:
        return _jigsawPath(cell, col: col, row: row, tabSize: tabSize);
    }
  }

  Path _jigsawPath(
    Rect cell, {
    required int col,
    required int row,
    required double tabSize,
  }) {
    final path = Path()..moveTo(cell.left, cell.top);
    _drawClassicKnob(
      path,
      from: Offset(cell.left, cell.top),
      to: Offset(cell.right, cell.top),
      edge: topEdge(col, row),
      outward: const Offset(0, -1),
      tabSize: cell.height * tabSize,
    );
    _drawClassicKnob(
      path,
      from: Offset(cell.right, cell.top),
      to: Offset(cell.right, cell.bottom),
      edge: rightEdge(col, row),
      outward: const Offset(1, 0),
      tabSize: cell.width * tabSize,
    );
    _drawClassicKnob(
      path,
      from: Offset(cell.right, cell.bottom),
      to: Offset(cell.left, cell.bottom),
      edge: bottomEdge(col, row),
      outward: const Offset(0, 1),
      tabSize: cell.height * tabSize,
    );
    _drawClassicKnob(
      path,
      from: Offset(cell.left, cell.bottom),
      to: Offset(cell.left, cell.top),
      edge: leftEdge(col, row),
      outward: const Offset(-1, 0),
      tabSize: cell.width * tabSize,
    );
    path.close();
    return path;
  }

  /// Traditioneller runder Puzzle-Zapfen (weich, nicht spitz).
  void _drawClassicKnob(
    Path path, {
    required Offset from,
    required Offset to,
    required JigsawEdge edge,
    required Offset outward,
    required double tabSize,
  }) {
    if (edge == JigsawEdge.flat) {
      path.lineTo(to.dx, to.dy);
      return;
    }

    final along = to - from;
    final length = along.distance;
    if (length <= 0) {
      path.lineTo(to.dx, to.dy);
      return;
    }

    final dir = along / length;
    final sign = edge == JigsawEdge.tab ? 1.0 : -1.0;
    final bump = outward * (tabSize * sign);

    final neckStart = from + dir * (length * 0.30);
    final neckEnd = from + dir * (length * 0.70);
    final mid = from + dir * (length * 0.5) + bump;
    final headLeft = mid - dir * (length * 0.13) + bump * 0.35;
    final headRight = mid + dir * (length * 0.13) + bump * 0.35;

    path.lineTo(neckStart.dx, neckStart.dy);
    path.cubicTo(
      neckStart.dx + bump.dx * 0.2,
      neckStart.dy + bump.dy * 0.2,
      headLeft.dx,
      headLeft.dy,
      mid.dx,
      mid.dy,
    );
    path.cubicTo(
      headRight.dx,
      headRight.dy,
      neckEnd.dx + bump.dx * 0.2,
      neckEnd.dy + bump.dy * 0.2,
      neckEnd.dx,
      neckEnd.dy,
    );
    path.lineTo(to.dx, to.dy);
  }

  Path _wavePath(
    Rect cell, {
    required int col,
    required int row,
  }) {
    final ampX = cell.width * 0.08;
    final ampY = cell.height * 0.08;
    final path = Path()..moveTo(cell.left, cell.top);

    // Oben: teilt Kante mit Teil darüber
    final topOut = row == 0
        ? 0.0
        : (_horizontalOut[row - 1][col] ? -1.0 : 1.0);
    _drawWave(
      path,
      from: Offset(cell.left, cell.top),
      to: Offset(cell.right, cell.top),
      outward: const Offset(0, -1),
      amplitude: ampY * topOut,
      flat: row == 0,
    );

    final rightOut = col == columns - 1
        ? 0.0
        : (_verticalOut[row][col] ? 1.0 : -1.0);
    _drawWave(
      path,
      from: Offset(cell.right, cell.top),
      to: Offset(cell.right, cell.bottom),
      outward: const Offset(1, 0),
      amplitude: ampX * rightOut,
      flat: col == columns - 1,
    );

    final bottomOut = row == rows - 1
        ? 0.0
        : (_horizontalOut[row][col] ? 1.0 : -1.0);
    _drawWave(
      path,
      from: Offset(cell.right, cell.bottom),
      to: Offset(cell.left, cell.bottom),
      outward: const Offset(0, 1),
      amplitude: ampY * bottomOut,
      flat: row == rows - 1,
    );

    final leftOut = col == 0
        ? 0.0
        : (_verticalOut[row][col - 1] ? -1.0 : 1.0);
    _drawWave(
      path,
      from: Offset(cell.left, cell.bottom),
      to: Offset(cell.left, cell.top),
      outward: const Offset(-1, 0),
      amplitude: ampX * leftOut,
      flat: col == 0,
    );

    path.close();
    return path;
  }

  void _drawWave(
    Path path, {
    required Offset from,
    required Offset to,
    required Offset outward,
    required double amplitude,
    required bool flat,
  }) {
    if (flat || amplitude.abs() < 0.01) {
      path.lineTo(to.dx, to.dy);
      return;
    }

    final along = to - from;
    final length = along.distance;
    if (length <= 0) {
      path.lineTo(to.dx, to.dy);
      return;
    }
    final dir = along / length;
    final mid = from + dir * (length * 0.5);
    final peak = mid + outward * amplitude;
    final c1 = from + dir * (length * 0.25) + outward * (amplitude * 0.2);
    final c2 = from + dir * (length * 0.75) + outward * (amplitude * 0.2);

    path.cubicTo(c1.dx, c1.dy, peak.dx, peak.dy, mid.dx, mid.dy);
    path.cubicTo(peak.dx, peak.dy, c2.dx, c2.dy, to.dx, to.dy);
  }
}
