import 'dart:math';

import 'package:flutter/material.dart';

import '../models/coloring_page.dart';

/// Puzzle-Spiel: Bild in Teile zerlegen und per Drag & Drop lösen.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.puzzle});

  final ColoringPage puzzle;

  static const int gridSize = 3;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  static const _gridSize = PuzzleScreen.gridSize;

  late List<int> _slots;
  bool _solved = false;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    final random = Random();
    do {
      _slots = List<int>.generate(_gridSize * _gridSize, (i) => i)..shuffle(random);
    } while (_isSolved());
    _solved = false;
  }

  bool _isSolved() {
    for (var i = 0; i < _slots.length; i++) {
      if (_slots[i] != i) return false;
    }
    return true;
  }

  void _swapSlots(int from, int to) {
    if (from == to) return;
    setState(() {
      final temp = _slots[from];
      _slots[from] = _slots[to];
      _slots[to] = temp;
      _solved = _isSolved();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final boardSize = min(size.width * 0.55, size.height * 0.78);

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
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_solved) ...[
                        Text(
                          'Geschafft!',
                          style: TextStyle(
                            color: const Color(0xFFFFD56A),
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: const Color(0xFFFFD56A).withValues(alpha: 0.6),
                                blurRadius: 16,
                              ),
                              const Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: boardSize,
                        height: boardSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _gridSize,
                              ),
                              itemCount: _gridSize * _gridSize,
                              itemBuilder: (context, slotIndex) {
                                final pieceIndex = _slots[slotIndex];
                                return _PuzzleSlot(
                                  slotIndex: slotIndex,
                                  pieceIndex: pieceIndex,
                                  assetPath: widget.puzzle.assetPath,
                                  gridSize: _gridSize,
                                  onSwap: _swapSlots,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!_solved)
                        Text(
                          'Ziehe die Teile, um das Bild zu lösen',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
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
                  right: 16,
                  child: _SilverIconButton(
                    icon: Icons.shuffle_rounded,
                    onPressed: () => setState(_shuffle),
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

class _PuzzleSlot extends StatelessWidget {
  const _PuzzleSlot({
    required this.slotIndex,
    required this.pieceIndex,
    required this.assetPath,
    required this.gridSize,
    required this.onSwap,
  });

  final int slotIndex;
  final int pieceIndex;
  final String assetPath;
  final int gridSize;
  final void Function(int from, int to) onSwap;

  @override
  Widget build(BuildContext context) {
    final piece = _PuzzlePieceImage(
      assetPath: assetPath,
      pieceIndex: pieceIndex,
      gridSize: gridSize,
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != slotIndex,
      onAcceptWithDetails: (details) => onSwap(details.data, slotIndex),
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        return LongPressDraggable<int>(
          data: slotIndex,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 90,
              height: 90,
              child: piece,
            ),
          ),
          childWhenDragging: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: isHighlighted
                    ? const Color(0xFFFFD56A)
                    : Colors.white.withValues(alpha: 0.35),
                width: isHighlighted ? 2 : 0.5,
              ),
            ),
            child: piece,
          ),
        );
      },
    );
  }
}

class _PuzzlePieceImage extends StatelessWidget {
  const _PuzzlePieceImage({
    required this.assetPath,
    required this.pieceIndex,
    required this.gridSize,
  });

  final String assetPath;
  final int pieceIndex;
  final int gridSize;

  @override
  Widget build(BuildContext context) {
    final row = pieceIndex ~/ gridSize;
    final col = pieceIndex % gridSize;
    final alignmentX =
        gridSize > 1 ? -1.0 + 2.0 * col / (gridSize - 1) : 0.0;
    final alignmentY =
        gridSize > 1 ? -1.0 + 2.0 * row / (gridSize - 1) : 0.0;

    return ClipRect(
      child: Align(
        alignment: Alignment(alignmentX, alignmentY),
        widthFactor: 1 / gridSize,
        heightFactor: 1 / gridSize,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
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
          child: Icon(
            icon,
            color: const Color(0xFF243044),
            size: 22,
          ),
        ),
      ),
    );
  }
}
