import 'dart:math' as math;
import 'dart:ui';

/// Orientierung einer Puzzle-Kante: Zahn nach außen, Bucht nach innen, oder flach.
enum JigsawEdge { flat, tab, blank }

/// Erzeugt ineinandergreifende Jigsaw-Kanten für ein Raster.
class JigsawLayout {
  JigsawLayout({
    required this.columns,
    required this.rows,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    _buildEdges();
  }

  final int columns;
  final int rows;
  final math.Random _random;

  /// Horizontale Kanten zwischen Reihen: [row][col] = Kante unterhalb von row.
  /// `true` = Zahn zeigt nach unten (unteres Teil hat Bucht).
  late final List<List<bool>> _horizontalTabs;

  /// Vertikale Kanten zwischen Spalten: [row][col] = Kante rechts von col.
  /// `true` = Zahn zeigt nach rechts (rechtes Teil hat Bucht).
  late final List<List<bool>> _verticalTabs;

  int get pieceCount => columns * rows;

  void _buildEdges() {
    _horizontalTabs = List.generate(
      rows - 1,
      (_) => List.generate(columns, (_) => _random.nextBool()),
    );
    _verticalTabs = List.generate(
      rows,
      (_) => List.generate(columns - 1, (_) => _random.nextBool()),
    );
  }

  JigsawEdge topEdge(int col, int row) {
    if (row == 0) return JigsawEdge.flat;
    // Kante über diesem Teil = horizontale Kante von row-1.
    // true = Zahn nach unten → dieses Teil hat Bucht oben.
    return _horizontalTabs[row - 1][col] ? JigsawEdge.blank : JigsawEdge.tab;
  }

  JigsawEdge bottomEdge(int col, int row) {
    if (row == rows - 1) return JigsawEdge.flat;
    return _horizontalTabs[row][col] ? JigsawEdge.tab : JigsawEdge.blank;
  }

  JigsawEdge leftEdge(int col, int row) {
    if (col == 0) return JigsawEdge.flat;
    return _verticalTabs[row][col - 1] ? JigsawEdge.blank : JigsawEdge.tab;
  }

  JigsawEdge rightEdge(int col, int row) {
    if (col == columns - 1) return JigsawEdge.flat;
    return _verticalTabs[row][col] ? JigsawEdge.tab : JigsawEdge.blank;
  }

  /// Bounding-Box eines Teils inkl. herausstehender Zähne, relativ zum Board.
  Rect pieceBounds({
    required int col,
    required int row,
    required Size boardSize,
    double tabSize = 0.22,
  }) {
    final cellW = boardSize.width / columns;
    final cellH = boardSize.height / rows;
    final tabW = cellW * tabSize;
    final tabH = cellH * tabSize;

    var left = col * cellW;
    var top = row * cellH;
    var right = left + cellW;
    var bottom = top + cellH;

    if (leftEdge(col, row) == JigsawEdge.tab) left -= tabW;
    if (rightEdge(col, row) == JigsawEdge.tab) right += tabW;
    if (topEdge(col, row) == JigsawEdge.tab) top -= tabH;
    if (bottomEdge(col, row) == JigsawEdge.tab) bottom += tabH;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Jigsaw-Pfad für ein Teil in Board-Koordinaten.
  Path piecePath({
    required int col,
    required int row,
    required Size boardSize,
    double tabSize = 0.22,
  }) {
    final cellW = boardSize.width / columns;
    final cellH = boardSize.height / rows;
    final left = col * cellW;
    final top = row * cellH;
    final right = left + cellW;
    final bottom = top + cellH;

    final path = Path();
    path.moveTo(left, top);

    _drawEdge(
      path,
      from: Offset(left, top),
      to: Offset(right, top),
      edge: topEdge(col, row),
      outward: const Offset(0, -1),
      tabSize: cellH * tabSize,
    );
    _drawEdge(
      path,
      from: Offset(right, top),
      to: Offset(right, bottom),
      edge: rightEdge(col, row),
      outward: const Offset(1, 0),
      tabSize: cellW * tabSize,
    );
    _drawEdge(
      path,
      from: Offset(right, bottom),
      to: Offset(left, bottom),
      edge: bottomEdge(col, row),
      outward: const Offset(0, 1),
      tabSize: cellH * tabSize,
    );
    _drawEdge(
      path,
      from: Offset(left, bottom),
      to: Offset(left, top),
      edge: leftEdge(col, row),
      outward: const Offset(-1, 0),
      tabSize: cellW * tabSize,
    );
    path.close();
    return path;
  }

  void _drawEdge(
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

    // Start der Bucht/des Zahns (~35–65 % der Kante).
    final neckStart = from + dir * (length * 0.34);
    final neckEnd = from + dir * (length * 0.66);
    final mid = from + dir * (length * 0.5) + bump;

    final ctrl1 = neckStart + bump * 0.15 + dir * (length * 0.02);
    final ctrl2 = mid - dir * (length * 0.08);
    final ctrl3 = mid + dir * (length * 0.08);
    final ctrl4 = neckEnd + bump * 0.15 - dir * (length * 0.02);

    path.lineTo(neckStart.dx, neckStart.dy);
    path.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, mid.dx, mid.dy);
    path.cubicTo(ctrl3.dx, ctrl3.dy, ctrl4.dx, ctrl4.dy, neckEnd.dx, neckEnd.dy);
    path.lineTo(to.dx, to.dy);
  }
}
