import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import '../models/puzzle_settings.dart';
import '../painting/jigsaw_layout.dart';
import '../widgets/silver_back_button.dart';

/// Jigsaw-Puzzle: Board oben maximal groß, Tray unten (Phone-freundlich).
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({
    super.key,
    required this.puzzle,
    this.customImage,
  });

  final ColoringPage puzzle;

  /// Optional: ausgemaltes Bild (sonst Asset aus [puzzle]).
  final ImageProvider? customImage;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with TickerProviderStateMixin {
  static const _trayHeight = 108.0;
  /// Moderate Magnet-Zone — groß genug zum Treffen, ohne riesige Flächen.
  static const _magnetFactor = 0.38;
  static const _ghostOpacity = 0.07;

  late final ImageProvider _imageProvider;
  bool _imagePrecached = false;

  PuzzleDifficulty _difficulty = PuzzleDifficulty.medium;
  PuzzlePieceStyle _pieceStyle = PuzzlePieceStyle.jigsaw;

  late int _cols;
  late int _rows;
  late int _pieceCount;
  late JigsawLayout _layout;
  late List<int?> _board;
  late List<int> _tray;
  bool _solved = false;
  bool _revealing = false;
  bool _celebrating = false;
  int? _popPiece;
  int? _shakeSlot;
  int? _hoverSlot;

  late final AnimationController _celebrateController;
  late final AnimationController _revealController;
  late final AnimationController _popController;
  late final AnimationController _shakeController;

  /// Hochkant → in Landscape legen (270°).
  bool get _rotatePortrait => widget.puzzle.aspectRatio < 0.98;

  /// Anzeige-Seitenverhältnis nach Drehung (unverzerret).
  double get _displayAspect {
    final a = widget.puzzle.aspectRatio;
    if (a <= 0) return 1;
    return _rotatePortrait ? (1 / a) : a;
  }

  int get _placedCount => _board.whereType<int>().length;

  @override
  void initState() {
    super.initState();
    _imageProvider = widget.customImage ?? AssetImage(widget.puzzle.assetPath);
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
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
    _revealController.dispose();
    _popController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  static ({int cols, int rows}) gridForDisplayAspect(
    double aspect, {
    required int targetCount,
  }) {
    final a = aspect.clamp(0.45, 2.6);
    final minN = math.max(4, (targetCount * 0.65).round());
    final maxN = math.min(48, (targetCount * 1.35).round());
    var bestCols = 4;
    var bestRows = 3;
    var bestScore = double.infinity;

    for (var cols = 2; cols <= 9; cols++) {
      for (var rows = 2; rows <= 9; rows++) {
        final n = cols * rows;
        if (n < minN || n > maxN) continue;
        final cellAspect = a * rows / cols;
        final score =
            (cellAspect - 1).abs() * 3 + (n - targetCount).abs() * 0.08;
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
    final grid = gridForDisplayAspect(
      _displayAspect,
      targetCount: _difficulty.targetPieces,
    );
    _cols = grid.cols;
    _rows = grid.rows;
    _pieceCount = _cols * _rows;
    final random = math.Random();
    _layout = JigsawLayout(
      columns: _cols,
      rows: _rows,
      style: _pieceStyle,
      random: random,
    );
    _board = List<int?>.filled(_pieceCount, null);
    _tray = List<int>.generate(_pieceCount, (i) => i)..shuffle(random);
    _solved = false;
    _revealing = false;
    _celebrating = false;
    _popPiece = null;
    _shakeSlot = null;
    _hoverSlot = null;
    _celebrateController.value = 0;
    _revealController.value = 0;
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

  Future<void> _openSettings() async {
    HapticFeedback.selectionClick();
    var draftDifficulty = _difficulty;
    var draftStyle = _pieceStyle;

    final applied = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Einstellungen',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim, secondary) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Center(
                  child: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.min(
                          520,
                          MediaQuery.sizeOf(context).width * 0.88,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2B3B66),
                              Color(0xFF1A2744),
                              Color(0xFF121C33),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFFFFD56A).withValues(alpha: 0.55),
                            width: 1.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD56A).withValues(alpha: 0.2),
                              blurRadius: 28,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Puzzle-Zauber',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFFFE7A0),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Wie magisch soll dein Puzzle sein?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Abenteuer-Stufe',
                                  style: TextStyle(
                                    color: const Color(0xFFFFD56A)
                                        .withValues(alpha: 0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final d in PuzzleDifficulty.values)
                                    _SettingsChip(
                                      label: '${d.label} · ~${d.targetPieces}',
                                      selected: draftDifficulty == d,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setSheetState(
                                          () => draftDifficulty = d,
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Zauber-Form',
                                  style: TextStyle(
                                    color: const Color(0xFFFFD56A)
                                        .withValues(alpha: 0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final s in PuzzlePieceStyle.values)
                                    _SettingsChip(
                                      label: s.label,
                                      selected: draftStyle == s,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setSheetState(() => draftStyle = s);
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                draftStyle.hint,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: _FantasyDialogButton(
                                      label: 'Zurück',
                                      filled: false,
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _FantasyDialogButton(
                                      label: 'Los geht\'s!',
                                      filled: true,
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (applied == true && mounted) {
      setState(() {
        _difficulty = draftDifficulty;
        _pieceStyle = draftStyle;
        _reset();
      });
    }
  }

  Future<void> _onSolved() async {
    if (_revealing || _celebrating) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _revealing = true;
      _hoverSlot = null;
    });
    await _revealController.forward(from: 0);
    if (!mounted) return;
    setState(() => _celebrating = true);
    await _celebrateController.forward(from: 0);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _placePiece(int pieceId) {
    if (_board[pieceId] != null || _solved) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _tray.remove(pieceId);
      _board[pieceId] = pieceId;
      _popPiece = pieceId;
      _hoverSlot = null;
      _checkSolved();
    });
    _popController.forward(from: 0);
    if (_solved) {
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _onSolved();
      });
    }
  }

  void _rejectDrop(int nearSlot) {
    if (_solved) return;
    HapticFeedback.lightImpact();
    setState(() {
      _shakeSlot = nearSlot.clamp(0, _pieceCount - 1);
      _hoverSlot = null;
    });
    _shakeController.forward(from: 0);
  }

  void _setHover(int? slot) {
    if (_hoverSlot == slot || _solved) return;
    setState(() => _hoverSlot = slot);
  }

  void _returnPieceToTray(int slotIndex) {
    if (_solved) return;
    final pieceId = _board[slotIndex];
    if (pieceId == null) return;
    setState(() {
      _board[slotIndex] = null;
      _tray.add(pieceId);
      _tray.shuffle(math.Random());
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                  child: Row(
                    children: [
                      SilverBackButton(
                        size: 40,
                        iconSize: 20,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      SilverBackButton(
                        size: 40,
                        iconSize: 20,
                        icon: Icons.tune_rounded,
                        onPressed: _openSettings,
                      ),
                      const Spacer(),
                      _ProgressChip(
                        placed: _placedCount,
                        total: _pieceCount,
                      ),
                      const Spacer(),
                      SilverBackButton(
                        size: 40,
                        iconSize: 20,
                        icon: Icons.refresh_rounded,
                        onPressed: () => setState(_reset),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardSize = _fitBoard(
                          Size(constraints.maxWidth, constraints.maxHeight),
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
                            hoverSlot: _hoverSlot,
                            reveal: _revealController,
                            solved: _solved,
                            onAcceptPiece: _placePiece,
                            onHoverSlot: _setHover,
                            onReturnPiece: _returnPieceToTray,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (!_solved)
                  SizedBox(
                    height: _trayHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Tray-Teile proportional zum Board skalieren.
                          final boardSize = _fitBoard(
                            Size(
                              MediaQuery.sizeOf(context).width - 24,
                              math.max(
                                80,
                                MediaQuery.sizeOf(context).height -
                                    _trayHeight -
                                    70,
                              ),
                            ),
                          );
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
          ),
          if (_celebrating)
            _PuzzleCelebration(animation: _celebrateController),
        ],
      ),
    );
  }
}

class _FantasyDialogButton extends StatelessWidget {
  const _FantasyDialogButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: filled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF0C2),
                      Color(0xFFFFD56A),
                      Color(0xFFE0A93A),
                    ],
                  )
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: filled
                  ? const Color(0xFFFFE7A0)
                  : Colors.white.withValues(alpha: 0.28),
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD56A).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: filled
                    ? const Color(0xFF2A2410)
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsChip extends StatelessWidget {
  const _SettingsChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      const Color(0xFFFFD56A).withValues(alpha: 0.35),
                      const Color(0xFFFFB347).withValues(alpha: 0.22),
                    ],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFD56A)
                  : Colors.white.withValues(alpha: 0.2),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD56A).withValues(alpha: 0.22),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFFFF3C4)
                  : Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
    // Nur Sterne + Text — das fertige Bild bleibt einmal auf dem Board sichtbar.
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          final size = MediaQuery.sizeOf(context);

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.28 * t.clamp(0, 1)),
              ),
              ...List.generate(24, (i) {
                final seed = i * 37.0;
                final x = math.sin(seed) * 0.5 + 0.5;
                final y =
                    (0.08 + (t * (0.5 + (i % 5) * 0.08))).clamp(0.0, 1.0);
                final starSize = 6.0 + (i % 4) * 3.0;
                const colors = [
                  Color(0xFFFFD56A),
                  Color(0xFFFF85A1),
                  Color(0xFFC9A6FF),
                  Color(0xFF6EE0FF),
                  Color(0xFFB6F5C8),
                ];
                return Positioned(
                  left: size.width * x,
                  top: size.height * y,
                  child: Opacity(
                    opacity:
                        (1.0 - (t - 0.2).clamp(0.0, 1.0)).clamp(0.15, 1.0),
                    child: Icon(
                      i.isEven
                          ? Icons.auto_awesome_rounded
                          : Icons.star_rounded,
                      size: starSize,
                      color: colors[i % colors.length],
                    ),
                  ),
                );
              }),
              Center(
                child: Opacity(
                  opacity: Curves.easeOut.transform(t.clamp(0, 1)),
                  child: Transform.scale(
                    scale: 0.9 +
                        0.12 * Curves.elasticOut.transform(t.clamp(0, 1)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Wunderbar!',
                          style: TextStyle(
                            color: const Color(0xFFFFD56A),
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            shadows: [
                              Shadow(
                                color: const Color(0xFFFFD56A)
                                    .withValues(alpha: 0.55),
                                blurRadius: 16,
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

/// Landscape unverändert; Portrait: 270° drehen (= quarterTurns 3).
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
    required this.hoverSlot,
    required this.reveal,
    required this.solved,
    required this.onAcceptPiece,
    required this.onHoverSlot,
    required this.onReturnPiece,
  });

  static const padFraction = 0.045;

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
  final int? hoverSlot;
  final Animation<double> reveal;
  final bool solved;
  final void Function(int pieceId) onAcceptPiece;
  final void Function(int? slot) onHoverSlot;
  final void Function(int slotIndex) onReturnPiece;

  @override
  Widget build(BuildContext context) {
    final pad = math.max(boardSize.width, boardSize.height) * padFraction;
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
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.4,
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
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  children: [
                    // Ghost während des Spiels
                    if (!solved)
                      Positioned.fill(
                        child: Opacity(
                          opacity: ghostOpacity,
                          child: _PuzzleImageLayer(
                            imageProvider: imageProvider,
                            rotatePortrait: rotatePortrait,
                          ),
                        ),
                      ),
                    // Slot-Umrisse
                    if (!solved)
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
                              color: Colors.white.withValues(alpha: 0.28),
                              strokeWidth: 1.0,
                            ),
                          ),
                    // Hover: nur feiner goldener Pfad (kein Flächen-Fill)
                    if (!solved && hoverSlot != null && board[hoverSlot!] == null)
                      CustomPaint(
                        size: boardSize,
                        painter: _PathStrokePainter(
                          path: layout.piecePath(
                            col: hoverSlot! % layout.columns,
                            row: hoverSlot! ~/ layout.columns,
                            boardSize: boardSize,
                          ),
                          color: const Color(0xFFFFD56A).withValues(alpha: 0.85),
                          strokeWidth: 2.2,
                        ),
                      ),
                    // Fertig: volles Bild einblenden
                    if (solved)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: reveal,
                          builder: (context, child) {
                            return Opacity(
                              opacity: reveal.value.clamp(0.0, 1.0),
                              child: child,
                            );
                          },
                          child: _PuzzleImageLayer(
                            imageProvider: imageProvider,
                            rotatePortrait: rotatePortrait,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Unsichtbare Magnet-Zonen (keine farbigen Rechtecke)
          if (!solved)
            for (var i = 0; i < layout.pieceCount; i++)
              if (board[i] == null)
                Positioned(
                  left: pad + (i % layout.columns) * cellW - magnetPad,
                  top: pad + (i ~/ layout.columns) * cellH - magnetPad,
                  width: cellW + magnetPad * 2,
                  height: cellH + magnetPad * 2,
                  child: DragTarget<int>(
                    onWillAcceptWithDetails: (details) => details.data == i,
                    onAcceptWithDetails: (details) {
                      onHoverSlot(null);
                      onAcceptPiece(details.data);
                    },
                    onMove: (details) {
                      if (details.data == i) onHoverSlot(i);
                    },
                    onLeave: (_) {
                      if (hoverSlot == i) onHoverSlot(null);
                    },
                    builder: (context, candidate, rejected) {
                      return const SizedBox.expand();
                    },
                  ),
                ),
          // Platzierte Teile (während Reveal ausblenden)
          if (!solved)
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
            final t = Curves.easeOutBack.transform(popAnimation.value);
            return Transform.scale(scale: 0.92 + 0.1 * t, child: c);
          },
          child: child,
        );
      }
    } else {
      // Dezent: nur Outline wackelt, keine rote Fläche
      child = AnimatedBuilder(
        animation: shakeAnimation,
        builder: (context, _) {
          final t = shakeAnimation.value;
          final dx = math.sin(t * math.pi * 5) * 5 * (1 - t);
          return Transform.translate(
            offset: Offset(dx, 0),
            child: CustomPaint(
              painter: _PathStrokePainter(
                path: layout
                    .piecePath(col: col, row: row, boardSize: boardSize)
                    .shift(Offset(-bounds.left, -bounds.top)),
                color: const Color(0xFFFF8A8A).withValues(alpha: 0.7 * (1 - t)),
                strokeWidth: 2.0,
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
    const maxH = 88.0;
    const maxW = 96.0;
    var pieceH = maxH;
    var pieceW = pieceH * (sampleBounds.width / sampleBounds.height);
    if (pieceW > maxW) {
      pieceW = maxW;
      pieceH = pieceW * (sampleBounds.height / sampleBounds.width);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.3),
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
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: tray.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
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
      elevation: 12,
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
      childWhenDragging: Opacity(opacity: 0.22, child: trayVisual),
      child: trayVisual,
      onDragStarted: () => HapticFeedback.selectionClick(),
      onDragEnd: (details) {
        if (details.wasAccepted) return;
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
                    color: const Color(0xFFFFD56A).withValues(alpha: 0.18),
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
          ..strokeWidth = 2.8
          ..color = const Color(0xFFFFD56A).withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glow ? 1.5 : 1.15
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
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
