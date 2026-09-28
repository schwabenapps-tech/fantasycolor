/// Schwierigkeits-Stufe (Gruppe in den Einstellungen).
enum PuzzleTier {
  easy(
    label: 'Leicht',
    pieceOptions: [6, 12, 20],
  ),
  medium(
    label: 'Mittel',
    pieceOptions: [30, 42, 64],
  ),
  expert(
    label: 'Profi',
    pieceOptions: [80, 100, 120],
  );

  const PuzzleTier({
    required this.label,
    required this.pieceOptions,
  });

  final String label;
  final List<int> pieceOptions;

  /// Zoom ab Mittel (viele kleine Teile).
  bool get allowsZoom => this != PuzzleTier.easy;

  static PuzzleTier forPieceCount(int count) {
    for (final tier in PuzzleTier.values) {
      if (tier.pieceOptions.contains(count)) return tier;
    }
    if (count < 30) return PuzzleTier.easy;
    if (count < 80) return PuzzleTier.medium;
    return PuzzleTier.expert;
  }
}

/// Konkrete Puzzle-Schwierigkeit = Ziel-Stückzahl.
enum PuzzleDifficulty {
  easy6(targetPieces: 6, tier: PuzzleTier.easy),
  easy12(targetPieces: 12, tier: PuzzleTier.easy),
  easy20(targetPieces: 20, tier: PuzzleTier.easy),
  medium30(targetPieces: 30, tier: PuzzleTier.medium),
  medium42(targetPieces: 42, tier: PuzzleTier.medium),
  medium64(targetPieces: 64, tier: PuzzleTier.medium),
  expert80(targetPieces: 80, tier: PuzzleTier.expert),
  expert100(targetPieces: 100, tier: PuzzleTier.expert),
  expert120(targetPieces: 120, tier: PuzzleTier.expert);

  const PuzzleDifficulty({
    required this.targetPieces,
    required this.tier,
  });

  final int targetPieces;
  final PuzzleTier tier;

  String get label => tier.label;

  String get chipLabel => '$label · $targetPieces';

  bool get allowsZoom => tier.allowsZoom;

  static PuzzleDifficulty closestTo(int pieces) {
    PuzzleDifficulty best = PuzzleDifficulty.easy12;
    var bestDelta = 1 << 30;
    for (final d in PuzzleDifficulty.values) {
      final delta = (d.targetPieces - pieces).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = d;
      }
    }
    return best;
  }

  static List<PuzzleDifficulty> forTier(PuzzleTier tier) => [
        for (final d in PuzzleDifficulty.values)
          if (d.tier == tier) d,
      ];
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
