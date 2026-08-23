import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../painting/jigsaw_layout.dart';

/// Jigsaw-Puzzle: korrektes Seitenverhältnis, schmale Teile-Leiste, mehr Teile.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.puzzle});

  final ColoringPage puzzle;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  static const _trayWidth = 92.0;
  static const _targetPieceCount = 30;

  late int _cols;
  late int _rows;
  late int _pieceCount;
  late JigsawLayout _layout;
  late List<int?> _board;
  late List<int> _tray;
  bool _solved = false;

  /// Hochkant → seitlich legen (90°), damit es im Landscape größer wird.
  bool get _rotatePortrait => widget.puzzle.aspectRatio < 0.98;

  /// Anzeige-Seitenverhältnis (nach optionaler Drehung).
  double get _displayAspect {
    final a = widget.puzzle.aspectRatio;
    if (a <= 0) return 1;
    return _rotatePortrait ? (1 / a) : a;
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  /// Raster so wählen, dass Zellen ≈ quadratisch sind.
  ///
  /// Früher fest 5×6 auf Querformat-Boards → Zellen ~2× so breit wie hoch,
  /// deshalb wirkten die Teile „langgezogen“ (ohne Bildverzerrung).
  static ({int cols, int rows}) gridForDisplayAspect(double aspect) {
    final a = aspect.clamp(0.45, 2.6);
    var bestCols = 5;
    var bestRows = 6;
    var bestScore = double.infinity;

    for (var cols = 3; cols <= 8; cols++) {
      for (var rows = 3; rows <= 8; rows++) {
        final n = cols * rows;
        if (n < 20 || n > 36) continue;
        // cellW/cellH = displayAspect * rows / cols — Ziel ≈ 1
        final cellAspect = a * rows / cols;
        final score =
            (cellAspect - 1).abs() * 3 + (n - _targetPieceCount).abs() * 0.04;
        if (score < bestScore) {
          bestScore = score;
          bestCols = cols;
          bestRows = rows;
        }
      }
    }
    return (cols: bestCols, rows: bestRows);
  }

  void _reset() {
    final grid = gridForDisplayAspect(_displayAspect);
    _cols = grid.cols;
    _rows = grid.rows;
    _pieceCount = _cols * _rows;
    final random = math.Random();
    _layout = JigsawLayout(columns: _cols, rows: _rows, random: random);
    _board = List<int?>.filled(_pieceCount, null);
    _tray = List<int>.generate(_pieceCount, (i) => i)..shuffle(random);
    _solved = false;
  }

  void _checkSolved() {
    _solved = true;
    for (var i = 0; i < _pieceCount; i++) {
      if (_board[i] != i) {
        _solved = false;
        return;
      }
    }
  }

  void _placePiece(int pieceId, int slotIndex) {
    if (_board[slotIndex] != null || pieceId != slotIndex) return;
    setState(() {
      _tray.remove(pieceId);
      _board[slotIndex] = pieceId;
      _checkSolved();
    });
  }

  void _returnPieceToTray(int slotIndex) {
    final pieceId = _board[slotIndex];
    if (pieceId == null) return;
    setState(() {
      _board[slotIndex] = null;
      _tray.add(pieceId);
      _tray.shuffle(math.Random());
      _solved = false;
    });
  }

  Size _fitBoard(Size maxSize) {
    // Rahmen-Padding gehört zur Gesamtgröße – sonst wird abgeschnitten.
    const padFraction = _JigsawBoard.padFraction;
    final aspect = _displayAspect;
    if (aspect <= 0 ||
        maxSize.width <= 0 ||
        maxSize.height <= 0 ||
        !maxSize.width.isFinite ||
        !maxSize.height.isFinite) {
      return Size.zero;
    }

    late double boardW;
    late double boardH;

    if (aspect >= 1) {
      // Querformat: längere Seite = Breite → Pad hängt an boardW.
      boardW = maxSize.width / (1 + 2 * padFraction);
      boardH = boardW / aspect;
      final framedH = boardH + 2 * boardW * padFraction;
      if (framedH > maxSize.height) {
        boardH = maxSize.height / (1 + 2 * aspect * padFraction);
        boardW = boardH * aspect;
      }
    } else {
      // Hochformat-Anzeige: längere Seite = Höhe → Pad hängt an boardH.
      boardH = maxSize.height / (1 + 2 * padFraction);
      boardW = boardH * aspect;
      final framedW = boardW + 2 * boardH * padFraction;
      if (framedW > maxSize.width) {
        boardW = maxSize.width / (1 + 2 * padFraction / aspect);
        boardH = boardW / aspect;
      }
    }

    return Size(boardW, boardH);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/in_app_background.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                        child: Column(
                          children: [
                            if (_solved)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'Geschafft!',
                                  style: TextStyle(
                                    color: const Color(0xFFFFD56A),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    shadows: [
                                      Shadow(
                                        color: const Color(0xFFFFD56A)
                                            .withValues(alpha: 0.55),
                                        blurRadius: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final boardSize = _fitBoard(
                                    Size(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    ),
                                  );
                                  return Center(
                                    child: _JigsawBoard(
                                      boardSize: boardSize,
                                      layout: _layout,
                                      assetPath: widget.puzzle.assetPath,
                                      rotatePortrait: _rotatePortrait,
                                      board: _board,
                                      onAcceptPiece: _placePiece,
                                      onReturnPiece: _returnPieceToTray,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _trayWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Gleiche Fit-Logik wie das Board links.
                            final boardArea = Size(
                              math.max(
                                0,
                                MediaQuery.sizeOf(context).width -
                                    _trayWidth -
                                    24,
                              ),
                              constraints.maxHeight,
                            );
                            final boardSize = _fitBoard(boardArea);
                            return _JigsawTray(
                              tray: _tray,
                              layout: _layout,
                              assetPath: widget.puzzle.assetPath,
                              rotatePortrait: _rotatePortrait,
                              boardSize: boardSize,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  child: _SilverIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 8,
                  child: _SilverIconButton(
                    icon: Icons.refresh_rounded,
                    onPressed: () => setState(_reset),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bild unverzerrt: Landscape normal, Portrait um 90° gedreht.
class _PuzzleImageLayer extends StatelessWidget {
  const _PuzzleImageLayer({
    required this.assetPath,
    required this.boardSize,
    required this.rotatePortrait,
  });

  final String assetPath;
  final Size boardSize;
  final bool rotatePortrait;

  @override
  Widget build(BuildContext context) {
    if (!rotatePortrait) {
      return Image.asset(
        assetPath,
        fit: BoxFit.fill,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      );
    }

    // RotatedBox hält Layout + Mitte korrekt (kein OverflowBox-Versatz).
    return RotatedBox(
      quarterTurns: 3,
      child: Image.asset(
        assetPath,
        fit: BoxFit.fill,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _JigsawBoard extends StatelessWidget {
  const _JigsawBoard({
    required this.boardSize,
    required this.layout,
    required this.assetPath,
    required this.rotatePortrait,
    required this.board,
    required this.onAcceptPiece,
    required this.onReturnPiece,
  });

  static const padFraction = 0.06;

  final Size boardSize;
  final JigsawLayout layout;
  final String assetPath;
  final bool rotatePortrait;
  final List<int?> board;
  final void Function(int pieceId, int slotIndex) onAcceptPiece;
  final void Function(int slotIndex) onReturnPiece;

  @override
  Widget build(BuildContext context) {
    final pad =
        math.max(boardSize.width, boardSize.height) * padFraction;

    return SizedBox(
      width: boardSize.width + pad * 2,
      height: boardSize.height + pad * 2,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: pad,
            top: pad,
            width: boardSize.width,
            height: boardSize.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.18,
                        child: _PuzzleImageLayer(
                          assetPath: assetPath,
                          boardSize: boardSize,
                          rotatePortrait: rotatePortrait,
                        ),
                      ),
                    ),
                    for (var i = 0; i < layout.pieceCount; i++)
                      if (board[i] == null)
                        CustomPaint(
                          size: boardSize,
                          painter: _PathStrokePainter(
                            path: layout.piecePath(
                              col: i % layout.columns,
                              row: i ~/ layout.columns,
                              boardSize: boardSize,
                            ),
                            color: Colors.white.withValues(alpha: 0.32),
                            strokeWidth: 1.0,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
          for (var i = 0; i < layout.pieceCount; i++)
            _BoardPieceLayer(
              pieceIndex: i,
              placedPiece: board[i],
              layout: layout,
              assetPath: assetPath,
              rotatePortrait: rotatePortrait,
              boardSize: boardSize,
              pad: pad,
              onAcceptPiece: onAcceptPiece,
              onReturnPiece: onReturnPiece,
            ),
        ],
      ),
    );
  }
}

class _BoardPieceLayer extends StatelessWidget {
  const _BoardPieceLayer({
    required this.pieceIndex,
    required this.placedPiece,
    required this.layout,
    required this.assetPath,
    required this.rotatePortrait,
    required this.boardSize,
    required this.pad,
    required this.onAcceptPiece,
    required this.onReturnPiece,
  });

  final int pieceIndex;
  final int? placedPiece;
  final JigsawLayout layout;
  final String assetPath;
  final bool rotatePortrait;
  final Size boardSize;
  final double pad;
  final void Function(int pieceId, int slotIndex) onAcceptPiece;
  final void Function(int slotIndex) onReturnPiece;

  @override
  Widget build(BuildContext context) {
    final col = pieceIndex % layout.columns;
    final row = pieceIndex ~/ layout.columns;
    final bounds = layout.pieceBounds(
      col: col,
      row: row,
      boardSize: boardSize,
    );

    return Positioned(
      left: pad + bounds.left,
      top: pad + bounds.top,
      width: bounds.width,
      height: bounds.height,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          if (placedPiece != null) return false;
          return details.data == pieceIndex;
        },
        onAcceptWithDetails: (details) =>
            onAcceptPiece(details.data, pieceIndex),
        builder: (context, candidateData, rejectedData) {
          final hovering = candidateData.isNotEmpty;
          final wrong = rejectedData.isNotEmpty;

          if (placedPiece != null) {
            return GestureDetector(
              onLongPress: () => onReturnPiece(pieceIndex),
              child: _JigsawPieceVisual(
                pieceIndex: placedPiece!,
                layout: layout,
                assetPath: assetPath,
                rotatePortrait: rotatePortrait,
                boardSize: boardSize,
                withShadow: true,
              ),
            );
          }

          return ColoredBox(
            color: hovering
                ? const Color(0xFFFFD56A).withValues(alpha: 0.22)
                : wrong
                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.14)
                    : Colors.transparent,
          );
        },
      ),
    );
  }
}

class _JigsawTray extends StatelessWidget {
  const _JigsawTray({
    required this.tray,
    required this.layout,
    required this.assetPath,
    required this.rotatePortrait,
    required this.boardSize,
  });

  final List<int> tray;
  final JigsawLayout layout;
  final String assetPath;
  final bool rotatePortrait;
  final Size boardSize;

  @override
  Widget build(BuildContext context) {
    // Einheitliche Tray-Box am Teil-Bounding (inkl. Zähne), nicht nur an der Zelle.
    final sampleBounds = layout.pieceBounds(
      col: 0,
      row: 0,
      boardSize: boardSize,
    );
    final maxW = 74.0;
    final maxH = 78.0;
    var pieceW = maxW;
    var pieceH = pieceW * (sampleBounds.height / sampleBounds.width);
    if (pieceH > maxH) {
      pieceH = maxH;
      pieceW = pieceH * (sampleBounds.width / sampleBounds.height);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 48, 6, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.black.withValues(alpha: 0.28),
          border: Border.all(color: Colors.white24),
        ),
        child: tray.isEmpty
            ? Center(
                child: Icon(
                  Icons.extension_rounded,
                  color: Colors.white.withValues(alpha: 0.35),
                  size: 28,
                ),
              )
            : ListView.separated(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                itemCount: tray.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final pieceId = tray[index];
                  return Center(
                    child: _TrayJigsawPiece(
                      pieceId: pieceId,
                      layout: layout,
                      assetPath: assetPath,
                      rotatePortrait: rotatePortrait,
                      boardSize: boardSize,
                      width: pieceW,
                      height: pieceH,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _TrayJigsawPiece extends StatelessWidget {
  const _TrayJigsawPiece({
    required this.pieceId,
    required this.layout,
    required this.assetPath,
    required this.rotatePortrait,
    required this.boardSize,
    required this.width,
    required this.height,
  });

  final int pieceId;
  final JigsawLayout layout;
  final String assetPath;
  final bool rotatePortrait;
  final Size boardSize;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final col = pieceId % layout.columns;
    final row = pieceId ~/ layout.columns;
    final boardBounds = layout.pieceBounds(
      col: col,
      row: row,
      boardSize: boardSize,
    );

    // In der Leiste klein, beim Draggen in echter Board-Größe.
    final trayVisual = SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: _JigsawPieceVisual(
          pieceIndex: pieceId,
          layout: layout,
          assetPath: assetPath,
          rotatePortrait: rotatePortrait,
          boardSize: boardSize,
          withShadow: true,
        ),
      ),
    );

    final dragVisual = Material(
      color: Colors.transparent,
      elevation: 10,
      shadowColor: Colors.black54,
      child: SizedBox(
        width: boardBounds.width,
        height: boardBounds.height,
        child: _JigsawPieceVisual(
          pieceIndex: pieceId,
          layout: layout,
          assetPath: assetPath,
          rotatePortrait: rotatePortrait,
          boardSize: boardSize,
          withShadow: true,
        ),
      ),
    );

    return Draggable<int>(
      data: pieceId,
      feedback: dragVisual,
      childWhenDragging: Opacity(opacity: 0.25, child: trayVisual),
      child: trayVisual,
    );
  }
}

class _JigsawPieceVisual extends StatelessWidget {
  const _JigsawPieceVisual({
    required this.pieceIndex,
    required this.layout,
    required this.assetPath,
    required this.rotatePortrait,
    required this.boardSize,
    this.withShadow = false,
  });

  final int pieceIndex;
  final JigsawLayout layout;
  final String assetPath;
  final bool rotatePortrait;
  final Size boardSize;
  final bool withShadow;

  @override
  Widget build(BuildContext context) {
    final col = pieceIndex % layout.columns;
    final row = pieceIndex ~/ layout.columns;
    final bounds = layout.pieceBounds(
      col: col,
      row: row,
      boardSize: boardSize,
    );
    final path = layout.piecePath(
      col: col,
      row: row,
      boardSize: boardSize,
    );
    final localPath = path.shift(Offset(-bounds.left, -bounds.top));

    return SizedBox(
      width: bounds.width,
      height: bounds.height,
      child: CustomPaint(
        painter: withShadow ? _JigsawShadowPainter(path: localPath) : null,
        foregroundPainter: _JigsawOutlinePainter(path: localPath),
        child: ClipPath(
          clipper: _PathClipper(localPath),
          child: Stack(
            children: [
              Positioned(
                left: -bounds.left,
                top: -bounds.top,
                width: boardSize.width,
                height: boardSize.height,
                child: _PuzzleImageLayer(
                  assetPath: assetPath,
                  boardSize: boardSize,
                  rotatePortrait: rotatePortrait,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathClipper extends CustomClipper<Path> {
  _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(covariant _PathClipper oldClipper) =>
      oldClipper.path != path;
}

class _JigsawOutlinePainter extends CustomPainter {
  _JigsawOutlinePainter({required this.path});

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _JigsawOutlinePainter oldDelegate) =>
      oldDelegate.path != path;
}

class _JigsawShadowPainter extends CustomPainter {
  _JigsawShadowPainter({required this.path});

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path.shift(const Offset(1.2, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(covariant _JigsawShadowPainter oldDelegate) =>
      oldDelegate.path != path;
}

class _PathStrokePainter extends CustomPainter {
  _PathStrokePainter({
    required this.path,
    required this.color,
    required this.strokeWidth,
  });

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PathStrokePainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color;
}

class _SilverIconButton extends StatelessWidget {
  const _SilverIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF7F9FC),
                Color(0xFFC5CCD8),
                Color(0xFF9AA3B5),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF243044), size: 22),
        ),
      ),
    );
  }
}
