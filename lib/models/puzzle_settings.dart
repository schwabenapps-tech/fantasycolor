/// Schwierigkeit = Ziel-Stückzahl (Raster wird passend gewählt).
enum PuzzleDifficulty {
  mini(targetPieces: 6, label: 'Mini'),
  easy(targetPieces: 12, label: 'Leicht'),
  medium(targetPieces: 20, label: 'Mittel'),
  hard(targetPieces: 30, label: 'Schwer'),
  expert(targetPieces: 42, label: 'Profi');

  const PuzzleDifficulty({
    required this.targetPieces,
    required this.label,
  });

  final int targetPieces;
  final String label;
}

/// Form der Puzzle-Teile.
enum PuzzlePieceStyle {
  /// Traditionelles Puzzle: runde Zapfen / Buchten (nicht spitz).
  jigsaw,

  /// Gerade Rechtecke.
  square,

  /// Abgerundete Kacheln.
  rounded,

  /// Wellenkanten (ohne Zapfen).
  wave,
}

extension PuzzlePieceStyleX on PuzzlePieceStyle {
  String get label => switch (this) {
        PuzzlePieceStyle.jigsaw => 'Klassisch',
        PuzzlePieceStyle.square => 'Viereck',
        PuzzlePieceStyle.rounded => 'Rund',
        PuzzlePieceStyle.wave => 'Wellen',
      };

  String get hint => switch (this) {
        PuzzlePieceStyle.jigsaw => 'Mit runden Zapfen wie echte Puzzles',
        PuzzlePieceStyle.square => 'Einfache Rechtecke',
        PuzzlePieceStyle.rounded => 'Weiche Ecken',
        PuzzlePieceStyle.wave => 'Geschwungene Kanten',
      };
}
