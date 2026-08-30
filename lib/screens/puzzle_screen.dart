import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../painting/jigsaw_layout.dart';
import '../widgets/silver_back_button.dart';

/// Jigsaw-Puzzle mit Magnet-Snap, Drop-Feedback und Celebration.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.puzzle});

  final ColoringPage puzzle;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with TickerProviderStateMixin {
  static const _trayWidth = 92.0;
  static const _targetPieceCount = 30;
  static const _magnetFactor = 0.72;
  static const _ghostOpacity = 0.08;

  late final ImageProvider _imageProvider;
  bool _imagePrecached = false;

  late int _cols;
  late int _rows;
  late int _pieceCount;
  late JigsawLayout _layout;
  late List<int?> _board;
  late List<int> _tray;
  bool _solved = false;
  bool _celebrating = false;
  int? _popPiece;
  int? _shakeSlot;

  late final AnimationController _celebrateController;
  late final AnimationController _popController;
  late final AnimationController _shakeController;

  /// Hochkant → seitlich legen (90°), damit es im Landscape größer wird.
  bool get _rotatePortrait => widget.puzzle.aspectRatio < 0.98;

  /// Anzeige-Seitenverhältnis (nach optionaler Drehung).
  double get _displayAspect {
    final a = widget.puzzle.aspectRatio;
    if (a <= 0) return 1;
    return _rotatePortrait ? (1 / a) : a;
  }

  int get _placedCount =>
      _board.whereType<int>().length;

  @override
  void initState() {
    super.initState();
    _imageProvider = AssetImage(widget.puzzle.assetPath);
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _popController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _popPiece = null);
        _popController.value = 0;
      }
    });
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _shakeSlot = null);
        _shakeController.value = 0;
      }
    });
    _reset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagePrecached) {
      _imagePrecached = true;
      precacheImage(_imageProvider, context);
    }
  }

  @override
  void dispose() {
    _celebrateController.dispose();
    _popController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// Raster so wählen, dass Zellen ≈ quadratisch sind.
  static ({int cols, int rows}) gridForDisplayAspect(double aspect) {
    final a = aspect.clamp(0.45, 2.6);
    var bestCols = 5;
    var bestRows = 6;
    var bestScore = double.infinity;

    for (var cols = 3; cols <= 8; cols++) {
      for (var rows = 3; rows <= 8; rows++) {
        final n = cols * rows;
        if (n < 20 || n > 36) continue;
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
    _celebrating = false;
    _popPiece = null;
    _shakeSlot = null;
    _celebrateController.value = 0;
    _popController.value = 0;
    _shakeController.value = 0;
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

  Future<void> _onSolved() async {
    if (_celebrating) return;
    setState(() => _celebrating = true);
    await _celebrateController.forward(from: 0);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _placePiece(int pieceId) {
    if (_board[pieceId] != null) return;
    setState(() {
      _tray.remove(pieceId);
      _board[pieceId] = pieceId;
      _popPiece = pieceId;
      _checkSolved();
    });
    _popController.forward(from: 0);
    if (_solved) {
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (mounted) _onSolved();
      });
    }
  }

  void _rejectDrop(int nearSlot) {
    setState(() => _shakeSlot = nearSlot.clamp(0, _pieceCount - 1));
    _shakeController.forward(from: 0);
  }

  void _returnPieceToTray(int slotIndex) {
    final pieceId = _board[slotIndex];
    if (pieceId == null) return;
    setState(() {
      _board[slotIndex] = null;
      _tray.add(pieceId);
      _tray.shuffle(math.Random());
      _solved = false;
      _celebrating = false;
    });
  }

  Size _fitBoard(Size maxSize) {
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
      boardW = maxSize.width / (1 + 2 * padFraction);
      boardH = boardW / aspect;
      final framedH = boardH + 2 * boardW * padFraction;
      if (framedH > maxSize.height) {
        boardH = maxSize.height / (1 + 2 * aspect * padFraction);
        boardW = boardH * aspect;
      }
    } else {
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
                            _ProgressChip(
                              placed: _placedCount,
                              total: _pieceCount,
                            ),
                            const SizedBox(height: 8),
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
                                      imageProvider: _imageProvider,
                                      rotatePortrait: _rotatePortrait,
                                      board: _board,
                                      ghostOpacity: _ghostOpacity,
                                      magnetFactor: _magnetFactor,
                                      popPiece: _popPiece,
                                      popAnimation: _popController,
                                      shakeSlot: _shakeSlot,
                                      shakeAnimation: _shakeController,
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
                              imageProvider: _imageProvider,
                              rotatePortrait: _rotatePortrait,
                              boardSize: boardSize,
                              onDragRejected: _rejectDrop,
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
                  child: SilverBackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 8,
                  child: SilverBackButton(
                    icon: Icons.refresh_rounded,
                    onPressed: () => setState(_reset),
                  ),
                ),
              ],
            ),
          ),
          if (_celebrating)
            _PuzzleCelebration(animation: _celebrateController),
        ],
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({
    required this.placed,
    required this.total,
  });

  final int placed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A44).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFD56A).withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          '$placed / $total',
          style: const TextStyle(
            color: Color(0xFFE8EEF8),
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _PuzzleCelebration extends StatelessWidget {
  const _PuzzleCelebration({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.35 * t.clamp(0, 1)),
              ),
              ...List.generate(28, (i) {
                final seed = i * 37.0;
                final x = math.sin(seed) * 0.5 + 0.5;
                final y = (0.15 + (t * (0.55 + (i % 5) * 0.08)))
                    .clamp(0.0, 1.0);
                final size = 6.0 + (i % 4) * 3.0;
                const colors = [
                  Color(0xFFFFD56A),
                  Color(0xFFFF85A1),
                  Color(0xFFC9A6FF),
                  Color(0xFF6EE0FF),
                  Color(0xFFB6F5C8),
                ];
                return Positioned(
                  left: MediaQuery.sizeOf(context).width * x,
                  top: MediaQuery.sizeOf(context).height * y,
                  child: Opacity(
                    opacity:
                        (1.0 - (t - 0.15).clamp(0.0, 1.0)).clamp(0.2, 1.0),
                    child: Transform.rotate(
                      angle: t * 4 + i,
                      child: Icon(
                        i.isEven
                            ? Icons.auto_awesome_rounded
                            : Icons.star_rounded,
                        size: size,
                        color: colors[i % colors.length],
                      ),
                    ),
                  ),
                );
              }),
              Center(
                child: Opacity(
                  opacity: Curves.easeOut.transform(t.clamp(0, 1)),
                  child: Transform.scale(
                    scale: 0.85 +
                        0.2 * Curves.elasticOut.transform(t.clamp(0, 1)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Wunderbar!',
                          style: TextStyle(
                            color: const Color(0xFFFFD56A),
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: const Color(0xFFFFD56A)
                                    .withValues(alpha: 0.6),
                                blurRadius: 18,
                              ),
                              const Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Puzzle geschafft',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bild unverzerrt: Landscape normal, Portrait um 90° gedreht.
class _PuzzleImageLayer extends StatelessWidget {
  const _PuzzleImageLayer({
    required this.imageProvider,
    required this.rotatePortrait,
  });

  final ImageProvider imageProvider;
  final bool rotatePortrait;

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: imageProvider,
      fit: BoxFit.fill,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );

    if (!rotatePortrait) return image;

    return RotatedBox(
      quarterTurns: 3,
      child: image,
    );
  }
}

class _JigsawBoard extends StatelessWidget {
  const _JigsawBoard({
    required this.boardSize,
    required this.layout,
    required this.imageProvider,
    required this.rotatePortrait,
    required this.board,
    required this.ghostOpacity,
    required this.magnetFactor,
    required this.popPiece,
    required this.popAnimation,
    required this.shakeSlot,
    required this.shakeAnimation,
    required this.onAcceptPiece,
    required this.onReturnPiece,
  });

  static const padFraction = 0.06;

  final Size boardSize;
  final JigsawLayout layout;
  final ImageProvider imageProvider;
  final bool rotatePortrait;
  final List<int?> board;
  final double ghostOpacity;
  final double magnetFactor;
  final int? popPiece;
  final Animation<double> popAnimation;
  final int? shakeSlot;
  final Animation<double> shakeAnimation;
  final void Function(int pieceId) onAcceptPiece;
  final void Function(int slotIndex) onReturnPiece;

  @override
  Widget build(BuildContext context) {
    final pad =
        math.max(boardSize.width, boardSize.height) * padFraction;
    final cellW = boardSize.width / layout.columns;
    final cellH = boardSize.height / layout.rows;
    final magnetPad = math.min(cellW, cellH) * magnetFactor * 0.5;

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
                        opacity: ghostOpacity,
                        child: _PuzzleImageLayer(
                          imageProvider: imageProvider,
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
          // Magnet-Zonen für leere Slots (erweiterte Hit-Area).
          for (var i = 0; i < layout.pieceCount; i++)
            if (board[i] == null)
              Positioned(
                left: pad + (i % layout.columns) * cellW - magnetPad,
                top: pad + (i ~/ layout.columns) * cellH - magnetPad,
                width: cellW + magnetPad * 2,
                height: cellH + magnetPad * 2,
                child: DragTarget<int>(
                  onWillAcceptWithDetails: (details) =>
                      details.data == i,
                  onAcceptWithDetails: (details) =>
                      onAcceptPiece(details.data),
                  builder: (context, candidate, rejected) {
                    final hovering = candidate.isNotEmpty;
                    final wrong = rejected.isNotEmpty;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: hovering
                            ? const Color(0xFFFFD56A).withValues(alpha: 0.2)
                            : wrong
                                ? const Color(0xFFFF6B6B)
                                    .withValues(alpha: 0.12)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  },
                ),
              ),
          for (var i = 0; i < layout.pieceCount; i++)
            if (board[i] != null || shakeSlot == i)
              _BoardPieceLayer(
                pieceIndex: i,
                placedPiece: board[i],
                layout: layout,
                imageProvider: imageProvider,
                rotatePortrait: rotatePortrait,
                boardSize: boardSize,
                pad: pad,
                popping: popPiece == i,
                popAnimation: popAnimation,
                shaking: shakeSlot == i,
                shakeAnimation: shakeAnimation,
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
    required this.imageProvider,
    required this.rotatePortrait,
    required this.boardSize,
    required this.pad,
    required this.popping,
    required this.popAnimation,
    required this.shaking,
    required this.shakeAnimation,
    required this.onReturnPiece,
  });

  final int pieceIndex;
  final int? placedPiece;
  final JigsawLayout layout;
  final ImageProvider imageProvider;
  final bool rotatePortrait;
  final Size boardSize;
  final double pad;
  final bool popping;
  final Animation<double> popAnimation;
  final bool shaking;
  final Animation<double> shakeAnimation;
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

    Widget child;
    if (placedPiece != null) {
      child = GestureDetector(
        onLongPress: () => onReturnPiece(pieceIndex),
        child: _JigsawPieceVisual(
          pieceIndex: placedPiece!,
          layout: layout,
          imageProvider: imageProvider,
          rotatePortrait: rotatePortrait,
          boardSize: boardSize,
          withShadow: true,
          glow: popping,
        ),
      );
      if (popping) {
        child = AnimatedBuilder(
          animation: popAnimation,
          builder: (context, c) {
            final t = Curves.elasticOut.transform(popAnimation.value);
            final scale = 0.86 + 0.18 * t;
            return Transform.scale(scale: scale, child: c);
          },
          child: child,
        );
      }
    } else {
      child = AnimatedBuilder(
        animation: shakeAnimation,
        builder: (context, _) {
          final t = shakeAnimation.value;
          final dx = math.sin(t * math.pi * 6) * 7 * (1 - t);
          return Transform.translate(
            offset: Offset(dx, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.28 * (1 - t)),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          );
        },
      );
    }

    return Positioned(
      left: pad + bounds.left,
      top: pad + bounds.top,
      width: bounds.width,
      height: bounds.height,
      child: child,
    );
  }
}

class _JigsawTray extends StatelessWidget {
  const _JigsawTray({
    required this.tray,
    required this.layout,
    required this.imageProvider,
    required this.rotatePortrait,
    required this.boardSize,
    required this.onDragRejected,
  });

  final List<int> tray;
  final JigsawLayout layout;
  final ImageProvider imageProvider;
  final bool rotatePortrait;
  final Size boardSize;
  final void Function(int nearSlot) onDragRejected;

  @override
  Widget build(BuildContext context) {
    final sampleBounds = layout.pieceBounds(
      col: 0,
      row: 0,
      boardSize: boardSize,
    );
    const maxW = 74.0;
    const maxH = 78.0;
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
                      imageProvider: imageProvider,
                      rotatePortrait: rotatePortrait,
                      boardSize: boardSize,
                      width: pieceW,
                      height: pieceH,
                      onDragRejected: onDragRejected,
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
    required this.imageProvider,
    required this.rotatePortrait,
    required this.boardSize,
    required this.width,
    required this.height,
    required this.onDragRejected,
  });

  final int pieceId;
  final JigsawLayout layout;
  final ImageProvider imageProvider;
  final bool rotatePortrait;
  final Size boardSize;
  final double width;
  final double height;
  final void Function(int nearSlot) onDragRejected;

  @override
  Widget build(BuildContext context) {
    final col = pieceId % layout.columns;
    final row = pieceId ~/ layout.columns;
    final boardBounds = layout.pieceBounds(
      col: col,
      row: row,
      boardSize: boardSize,
    );

    final trayVisual = SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: _JigsawPieceVisual(
          pieceIndex: pieceId,
          layout: layout,
          imageProvider: imageProvider,
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
          imageProvider: imageProvider,
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
      onDragEnd: (details) {
        if (details.wasAccepted) return;
        // Falscher Drop: Shake am eigenen Ziel-Slot als Hinweis.
        onDragRejected(pieceId);
      },
    );
  }
}

class _JigsawPieceVisual extends StatelessWidget {
  const _JigsawPieceVisual({
    required this.pieceIndex,
    required this.layout,
    required this.imageProvider,
    required this.rotatePortrait,
    required this.boardSize,
    this.withShadow = false,
    this.glow = false,
  });

  final int pieceIndex;
  final JigsawLayout layout;
  final ImageProvider imageProvider;
  final bool rotatePortrait;
  final Size boardSize;
  final bool withShadow;
  final bool glow;

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
        foregroundPainter: _JigsawOutlinePainter(
          path: localPath,
          glow: glow,
        ),
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
                  imageProvider: imageProvider,
                  rotatePortrait: rotatePortrait,
                ),
              ),
              if (glow)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xFFFFD56A).withValues(alpha: 0.22),
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
  _JigsawOutlinePainter({required this.path, this.glow = false});

  final Path path;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..color = const Color(0xFFFFD56A).withValues(alpha: 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glow ? 1.6 : 1.2
        ..color = glow
            ? const Color(0xFFFFD56A)
            : Colors.white.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _JigsawOutlinePainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.glow != glow;
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
