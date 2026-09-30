import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Schwierigkeits-Stufe (Gruppe in den Settings).
enum PuzzleTier {
  easy(
    label: 'Easy',
    pieceOptions: [6, 12, 20],
  ),
  medium(
    label: 'Medium',
    pieceOptions: [30, 42, 64],
  ),
  expert(
    label: 'Pro',
    pieceOptions: [80, 100, 120],
  );

  const PuzzleTier({
    required this.label,
    required this.pieceOptions,
  });

  final String label;
  final List<int> pieceOptions;

  /// Zoom ab Medium (viele kleine Teile).
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
        PuzzlePieceStyle.jigsaw => 'Classic',
        PuzzlePieceStyle.square => 'Square',
        PuzzlePieceStyle.rounded => 'Rounded',
        PuzzlePieceStyle.wave => 'Wave',
      };

  String get hint => switch (this) {
        PuzzlePieceStyle.jigsaw => 'Round tabs like real puzzles',
        PuzzlePieceStyle.square => 'Straight rectangles',
        PuzzlePieceStyle.rounded => 'Soft corners',
        PuzzlePieceStyle.wave => 'Curved edges',
      };
}

/// Persistierte Puzzle-Settings (Stückzahl + Stil).
class PuzzlePreferences {
  PuzzlePreferences._();

  static const _difficultyKey = 'puzzle_difficulty_v1';
  static const _styleKey = 'puzzle_piece_style_v1';

  static Future<({PuzzleDifficulty difficulty, PuzzlePieceStyle style})>
      load() async {
    final prefs = await SharedPreferences.getInstance();
    final difficulty = _parseDifficulty(prefs.getString(_difficultyKey)) ??
        PuzzleDifficulty.medium30;
    final style =
        _parseStyle(prefs.getString(_styleKey)) ?? PuzzlePieceStyle.jigsaw;
    return (difficulty: difficulty, style: style);
  }

  static Future<void> save({
    required PuzzleDifficulty difficulty,
    required PuzzlePieceStyle style,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_difficultyKey, difficulty.name);
    await prefs.setString(_styleKey, style.name);
  }

  static PuzzleDifficulty? _parseDifficulty(String? raw) {
    if (raw == null) return null;
    for (final d in PuzzleDifficulty.values) {
      if (d.name == raw) return d;
    }
    return null;
  }

  static PuzzlePieceStyle? _parseStyle(String? raw) {
    if (raw == null) return null;
    for (final s in PuzzlePieceStyle.values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}
