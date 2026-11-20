import 'dart:math' as math;
import 'dart:ui';

import '../models/puzzle_settings.dart';

/// Orientierung einer Puzzle-Kante: Zahn nach außen, Bucht nach innen, oder flach.
enum JigsawEdge { flat, tab, blank }

/// Erzeugt Puzzle-Pfade für ein Raster (Zapfen / Kacheln / Wellen).
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

  /// Versatz der Zapfen entlang der Kante (nur Offset-Stil), von links/oben.
  late final List<List<double>> _horizontalShift;
  late final List<List<double>> _verticalShift;

  int get pieceCount => columns * rows;

  bool get _useTabs => switch (style) {
        PuzzlePieceStyle.jigsaw ||
        PuzzlePieceStyle.oval ||
        PuzzlePieceStyle.block ||
        PuzzlePieceStyle.offset ||
        PuzzlePieceStyle.keyhole ||
        PuzzlePieceStyle.pointed ||
        PuzzlePieceStyle.cloud =>
          true,
        _ => false,
      };
  bool get _useWaves =>
      style == PuzzlePieceStyle.wave || style == PuzzlePieceStyle.ripple;

  void _buildEdges() {
    if (!_useTabs && !_useWaves) {
      _horizontalOut = const [];
      _verticalOut = const [];
      _horizontalShift = const [];
      _verticalShift = const [];
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
    final useShift = style == PuzzlePieceStyle.offset;
    _horizontalShift = List.generate(
      math.max(0, rows - 1),
      (_) => List.generate(
        columns,
        (_) => useShift ? (_random.nextBool() ? -0.13 : 0.13) : 0.0,
      ),
    );
    _verticalShift = List.generate(
      rows,
      (_) => List.generate(
        math.max(0, columns - 1),
        (_) => useShift ? (_random.nextBool() ? -0.13 : 0.13) : 0.0,
      ),
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

  /// Größte Teil-Bounding-Box (für einheitliche Tray-Skalierung).
  Size maxPieceSize({required Size boardSize, double tabSize = 0.24}) {
    var maxW = 0.0;
    var maxH = 0.0;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final b = pieceBounds(
          col: col,
          row: row,
          boardSize: boardSize,
          tabSize: tabSize,
        );
        maxW = math.max(maxW, b.width);
        maxH = math.max(maxH, b.height);
      }
    }
    return Size(maxW, maxH);
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
        return _wavePath(cell, col: col, row: row, peaks: 1);
      case PuzzlePieceStyle.ripple:
        return _wavePath(cell, col: col, row: row, peaks: 2);
      case PuzzlePieceStyle.jigsaw:
      case PuzzlePieceStyle.oval:
      case PuzzlePieceStyle.block:
      case PuzzlePieceStyle.offset:
      case PuzzlePieceStyle.keyhole:
      case PuzzlePieceStyle.pointed:
      case PuzzlePieceStyle.cloud:
        return _tabPath(cell, col: col, row: row, tabSize: tabSize);
    }
  }

  double _shiftForTop(int col, int row) =>
      row == 0 ? 0 : _horizontalShift[row - 1][col];
  double _shiftForBottom(int col, int row) =>
      row == rows - 1 ? 0 : _horizontalShift[row][col];
  double _shiftForLeft(int col, int row) =>
      col == 0 ? 0 : _verticalShift[row][col - 1];
  double _shiftForRight(int col, int row) =>
      col == columns - 1 ? 0 : _verticalShift[row][col];

  Path _tabPath(
    Rect cell, {
    required int col,
    required int row,
    required double tabSize,
  }) {
    final path = Path()..moveTo(cell.left, cell.top);

    void edge({
      required Offset from,
      required Offset to,
      required JigsawEdge edge,
      required Offset outward,
      required double size,
      required double shift,
      required bool flipShift,
    }) {
      final midShift = flipShift ? -shift : shift;
      switch (style) {
        case PuzzlePieceStyle.pointed:
          _drawPointedKnob(
            path,
            from: from,
            to: to,
            edge: edge,
            outward: outward,
            tabSize: size,
            midShift: midShift,
          );
        case PuzzlePieceStyle.cloud:
          _drawCloudKnob(
            path,
            from: from,
            to: to,
            edge: edge,
            outward: outward,
            tabSize: size,
            midShift: midShift,
          );
        case PuzzlePieceStyle.block:
          _drawBlockKnob(
            path,
            from: from,
            to: to,
            edge: edge,
            outward: outward,
            tabSize: size,
            midShift: midShift,
          );
        case PuzzlePieceStyle.oval:
          _drawClassicKnob(
            path,
            from: from,
            to: to,
            edge: edge,
            outward: outward,
            tabSize: size * 0.92,
            midShift: midShift,
            neckStartT: 0.22,
            neckEndT: 0.78,
            headWidthT: 0.18,
            headBulge: 0.55,
          );
        case PuzzlePieceStyle.keyhole:
          _drawKeyholeKnob(
            path,
            from: from,
            to: to,
            edge: edge,
            outward: outward,
            tabSize: size,
            midShift: midShift,
          );
        case PuzzlePieceStyle.jigsaw:
        case PuzzlePieceStyle.offset:
        case PuzzlePieceStyle.square:
        case PuzzlePieceStyle.rounded:
        case PuzzlePieceStyle.wave:
        case PuzzlePieceStyle.ripple:
          _drawClassicKnob(
            path,
            from: from,
            to: to,
            edge: edge,
            outward: outward,
            tabSize: size,
            midShift: midShift,
          );
      }
    }

    edge(
      from: Offset(cell.left, cell.top),
      to: Offset(cell.right, cell.top),
      edge: topEdge(col, row),
      outward: const Offset(0, -1),
      size: cell.height * tabSize,
      shift: _shiftForTop(col, row),
      flipShift: false,
    );
    edge(
      from: Offset(cell.right, cell.top),
      to: Offset(cell.right, cell.bottom),
      edge: rightEdge(col, row),
      outward: const Offset(1, 0),
      size: cell.width * tabSize,
      shift: _shiftForRight(col, row),
      flipShift: false,
    );
    edge(
      from: Offset(cell.right, cell.bottom),
      to: Offset(cell.left, cell.bottom),
      edge: bottomEdge(col, row),
      outward: const Offset(0, 1),
      size: cell.height * tabSize,
      shift: _shiftForBottom(col, row),
      flipShift: true,
    );
    edge(
      from: Offset(cell.left, cell.bottom),
      to: Offset(cell.left, cell.top),
      edge: leftEdge(col, row),
      outward: const Offset(-1, 0),
      size: cell.width * tabSize,
      shift: _shiftForLeft(col, row),
      flipShift: true,
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
    double midShift = 0,
    double neckStartT = 0.30,
    double neckEndT = 0.70,
    double headWidthT = 0.13,
    double headBulge = 0.35,
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
    final midT = (0.5 + midShift).clamp(0.28, 0.72);
    final halfNeck = (neckEndT - neckStartT) * 0.5;
    final neckStart = from + dir * (length * (midT - halfNeck));
    final neckEnd = from + dir * (length * (midT + halfNeck));
    final mid = from + dir * (length * midT) + bump;
    final headLeft = mid - dir * (length * headWidthT) + bump * headBulge;
    final headRight = mid + dir * (length * headWidthT) + bump * headBulge;

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

  /// Eckiger Block-Zapfen.
  void _drawBlockKnob(
    Path path, {
    required Offset from,
    required Offset to,
    required JigsawEdge edge,
    required Offset outward,
    required double tabSize,
    double midShift = 0,
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
    final midT = (0.5 + midShift).clamp(0.30, 0.70);
    final half = 0.14;
    final a = from + dir * (length * (midT - half));
    final b = from + dir * (length * (midT + half));
    final aOut = a + bump;
    final bOut = b + bump;

    path.lineTo(a.dx, a.dy);
    path.lineTo(aOut.dx, aOut.dy);
    path.lineTo(bOut.dx, bOut.dy);
    path.lineTo(b.dx, b.dy);
    path.lineTo(to.dx, to.dy);
  }

  /// Keyhole: eingeschnürter Hals, runder Kopf.
  void _drawKeyholeKnob(
    Path path, {
    required Offset from,
    required Offset to,
    required JigsawEdge edge,
    required Offset outward,
    required double tabSize,
    double midShift = 0,
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
    final midT = (0.5 + midShift).clamp(0.30, 0.70);
    final neckStart = from + dir * (length * (midT - 0.11));
    final neckEnd = from + dir * (length * (midT + 0.11));
    final pinchL = neckStart + bump * 0.22 + dir * (length * 0.01);
    final pinchR = neckEnd + bump * 0.22 - dir * (length * 0.01);
    final mid = from + dir * (length * midT) + bump;
    final headL = mid - dir * (length * 0.15) + bump * 0.42;
    final headR = mid + dir * (length * 0.15) + bump * 0.42;

    path.lineTo(neckStart.dx, neckStart.dy);
    path.cubicTo(
      pinchL.dx,
      pinchL.dy,
      headL.dx,
      headL.dy,
      mid.dx,
      mid.dy,
    );
    path.cubicTo(
      headR.dx,
      headR.dy,
      pinchR.dx,
      pinchR.dy,
      neckEnd.dx,
      neckEnd.dy,
    );
    path.lineTo(to.dx, to.dy);
  }

  /// Spitzer Diamant-Zapfen.
  void _drawPointedKnob(
    Path path, {
    required Offset from,
    required Offset to,
    required JigsawEdge edge,
    required Offset outward,
    required double tabSize,
    double midShift = 0,
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
    final midT = (0.5 + midShift).clamp(0.30, 0.70);
    final half = 0.16;

    final neckStart = from + dir * (length * (midT - half));
    final neckEnd = from + dir * (length * (midT + half));
    final tip = from + dir * (length * midT) + bump;
    final baseLeft = neckStart + bump * 0.12;
    final baseRight = neckEnd + bump * 0.12;

    path.lineTo(neckStart.dx, neckStart.dy);
    path.lineTo(baseLeft.dx, baseLeft.dy);
    path.lineTo(tip.dx, tip.dy);
    path.lineTo(baseRight.dx, baseRight.dy);
    path.lineTo(neckEnd.dx, neckEnd.dy);
    path.lineTo(to.dx, to.dy);
  }

  /// Weicher Wolken-Zapfen mit drei Lappen.
  void _drawCloudKnob(
    Path path, {
    required Offset from,
    required Offset to,
    required JigsawEdge edge,
    required Offset outward,
    required double tabSize,
    double midShift = 0,
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
    final midT = (0.5 + midShift).clamp(0.34, 0.66);

    final neckStart = from + dir * (length * (midT - 0.28));
    final neckEnd = from + dir * (length * (midT + 0.28));

    Offset lobe(double t, double height) =>
        from + dir * (length * t) + bump * height;

    path.lineTo(neckStart.dx, neckStart.dy);
    final l1 = lobe(midT - 0.16, 0.55);
    final l2 = lobe(midT, 1.05);
    final l3 = lobe(midT + 0.16, 0.55);
    path.cubicTo(
      neckStart.dx + bump.dx * 0.15,
      neckStart.dy + bump.dy * 0.15,
      l1.dx - dir.dx * length * 0.04,
      l1.dy - dir.dy * length * 0.04,
      l1.dx,
      l1.dy,
    );
    path.cubicTo(
      l1.dx + dir.dx * length * 0.05,
      l1.dy + dir.dy * length * 0.05,
      l2.dx - dir.dx * length * 0.05,
      l2.dy - dir.dy * length * 0.05,
      l2.dx,
      l2.dy,
    );
    path.cubicTo(
      l2.dx + dir.dx * length * 0.05,
      l2.dy + dir.dy * length * 0.05,
      l3.dx - dir.dx * length * 0.04,
      l3.dy - dir.dy * length * 0.04,
      l3.dx,
      l3.dy,
    );
    path.cubicTo(
      l3.dx + dir.dx * length * 0.04,
      l3.dy + dir.dy * length * 0.04,
      neckEnd.dx + bump.dx * 0.15,
      neckEnd.dy + bump.dy * 0.15,
      neckEnd.dx,
      neckEnd.dy,
    );
    path.lineTo(to.dx, to.dy);
  }

  Path _wavePath(
    Rect cell, {
    required int col,
    required int row,
    int peaks = 1,
  }) {
    final ampScale = peaks > 1 ? 0.10 : 0.08;
    final ampX = cell.width * ampScale;
    final ampY = cell.height * ampScale;
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
      peaks: peaks,
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
      peaks: peaks,
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
      peaks: peaks,
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
      peaks: peaks,
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
    int peaks = 1,
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
    final count = peaks.clamp(1, 3);

    var cursor = from;
    for (var i = 0; i < count; i++) {
      final startT = i / count;
      final endT = (i + 1) / count;
      final midT = (startT + endT) * 0.5;
      final segStart = from + dir * (length * startT);
      final segEnd = from + dir * (length * endT);
      final mid = from + dir * (length * midT);
      final peak = mid + outward * amplitude;
      final c1 = segStart + dir * (length * (endT - startT) * 0.25) +
          outward * (amplitude * 0.2);
      final c2 = segStart + dir * (length * (endT - startT) * 0.75) +
          outward * (amplitude * 0.2);
      if (i == 0 && (cursor - segStart).distance > 0.01) {
        path.lineTo(segStart.dx, segStart.dy);
      }
      path.cubicTo(c1.dx, c1.dy, peak.dx, peak.dy, mid.dx, mid.dy);
      path.cubicTo(peak.dx, peak.dy, c2.dx, c2.dy, segEnd.dx, segEnd.dy);
      cursor = segEnd;
    }
    path.lineTo(to.dx, to.dy);
  }
}
