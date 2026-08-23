import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../painting/jigsaw_layout.dart';

/// Jigsaw-Puzzle: korrektes Seitenverhältnis, schmale Teile-Leiste, mehr Teile.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.puzzle});

  final ColoringPage puzzle;

  static const int columns = 5;
  static const int rows = 6;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  static const _cols = PuzzleScreen.columns;
  static const _rows = PuzzleScreen.rows;
  static const _pieceCount = _cols * _rows;
  static const _trayWidth = 92.0;

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

  void _reset() {
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
    final aspect = _displayAspect;
    var width = maxSize.width;
    var height = width / aspect;
    if (height > maxSize.height) {
      height = maxSize.height;
      width = height * aspect;
    }
    return Size(width, height);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

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
                        padding: const EdgeInsets.fromLTRB(48, 12, 8, 12),
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Board-Größe analog berechnen für Teil-Proportionen.
                          final boardSize = _fitBoard(
                            Size(
                              size.width - _trayWidth - 56,
                              size.height * 0.82,
                            ),
                          );
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
        filterQuality: FilterQuality.medium,
      );
    }

    // Portrait um 90° gegen den Uhrzeigersinn – korrekt wenn Handy quer gehalten wird.
    return ClipRect(
      child: Transform.rotate(
        angle: -math.pi / 2,
        alignment: Alignment.center,
        child: OverflowBox(
          alignment: Alignment.center,
          minWidth: boardSize.height,
          maxWidth: boardSize.height,
          minHeight: boardSize.width,
          maxHeight: boardSize.width,
          child: SizedBox(
            width: boardSize.height,
            height: boardSize.width,
            child: Image.asset(
              assetPath,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
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

  final Size boardSize;
  final JigsawLayout layout;
  final String assetPath;
  final bool rotatePortrait;
  final List<int?> board;
  final void Function(int pieceId, int slotIndex) onAcceptPiece;
  final void Function(int slotIndex) onReturnPiece;

  @override
  Widget build(BuildContext context) {
    final pad = math.max(boardSize.width, boardSize.height) * 0.06;

    return SizedBox(
      width: boardSize.width + pad * 2,
      height: boardSize.height + pad * 2,
      child: Stack(
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
    // Einheitliche Teil-Größe in der Leiste (Seitenverhältnis der Zelle).
    final cellW = boardSize.width / layout.columns;
    final cellH = boardSize.height / layout.rows;
    final maxW = 72.0;
    final pieceW = math.min(maxW, cellW * 0.85);
    final pieceH = pieceW * (cellH / cellW);

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
