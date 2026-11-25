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

  /// Classic mit ovalen Zapfen.
  oval,

  /// Classic mit eckigen / blockigen Zapfen.
  block,

  /// Classic mit versetzten Zapfen.
  offset,

  /// Classic mit eingeschnürtem Keyhole-Hals.
  keyhole,

  /// Spitze / rautenförmige Zapfen.
  pointed,

  /// Weiche „Wolken“-Zapfen.
  cloud,

  /// Gerade Rechtecke.
  square,

  /// Abgerundete Kacheln.
  rounded,

  /// Wellenkanten (ohne Zapfen).
  wave,

  /// Doppelwelle — spielerischere Kanten.
  ripple,
}

extension PuzzlePieceStyleX on PuzzlePieceStyle {
  String get label => switch (this) {
        PuzzlePieceStyle.jigsaw => 'Classic',
        PuzzlePieceStyle.oval => 'Oval',
        PuzzlePieceStyle.block => 'Block',
        PuzzlePieceStyle.offset => 'Offset',
        PuzzlePieceStyle.keyhole => 'Keyhole',
        PuzzlePieceStyle.pointed => 'Pointed',
        PuzzlePieceStyle.cloud => 'Cloud',
        PuzzlePieceStyle.square => 'Square',
        PuzzlePieceStyle.rounded => 'Rounded',
        PuzzlePieceStyle.wave => 'Wave',
        PuzzlePieceStyle.ripple => 'Ripple',
      };

  String get hint => switch (this) {
        PuzzlePieceStyle.jigsaw => 'Round tabs like real puzzles',
        PuzzlePieceStyle.oval => 'Longer oval tabs',
        PuzzlePieceStyle.block => 'Chunky rectangular tabs',
        PuzzlePieceStyle.offset => 'Tabs shifted off-center',
        PuzzlePieceStyle.keyhole => 'Pinched keyhole necks',
        PuzzlePieceStyle.pointed => 'Sharp diamond tabs',
        PuzzlePieceStyle.cloud => 'Soft fluffy tabs',
        PuzzlePieceStyle.square => 'Straight rectangles',
        PuzzlePieceStyle.rounded => 'Soft corners',
        PuzzlePieceStyle.wave => 'Curved edges',
        PuzzlePieceStyle.ripple => 'Double wavy edges',
      };
}

/// Landscape-Tray: rechts für Rechtshänder, links für Linkshänder.
enum PuzzleHandedness {
  rightHanded,
  leftHanded,
}

extension PuzzleHandednessX on PuzzleHandedness {
  /// Tray auf der rechten Seite?
  bool get trayOnRight => this == PuzzleHandedness.rightHanded;
}

/// Persistierte Puzzle-Settings (Stückzahl + Stil + Händigkeit).
class PuzzlePreferences {
  PuzzlePreferences._();

  static const _difficultyKey = 'puzzle_difficulty_v1';
  static const _styleKey = 'puzzle_piece_style_v1';
  static const _handednessKey = 'puzzle_handedness_v1';

  static Future<
      ({
        PuzzleDifficulty difficulty,
        PuzzlePieceStyle style,
        PuzzleHandedness handedness,
      })> load() async {
    final prefs = await SharedPreferences.getInstance();
    final difficulty = _parseDifficulty(prefs.getString(_difficultyKey)) ??
        PuzzleDifficulty.medium30;
    final style =
        _parseStyle(prefs.getString(_styleKey)) ?? PuzzlePieceStyle.jigsaw;
    final handedness = _parseHandedness(prefs.getString(_handednessKey)) ??
        PuzzleHandedness.rightHanded;
    return (
      difficulty: difficulty,
      style: style,
      handedness: handedness,
    );
  }

  static Future<void> save({
    required PuzzleDifficulty difficulty,
    required PuzzlePieceStyle style,
    required PuzzleHandedness handedness,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_difficultyKey, difficulty.name);
    await prefs.setString(_styleKey, style.name);
    await prefs.setString(_handednessKey, handedness.name);
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

  static PuzzleHandedness? _parseHandedness(String? raw) {
    if (raw == null) return null;
    for (final h in PuzzleHandedness.values) {
      if (h.name == raw) return h;
    }
    return null;
  }
}
