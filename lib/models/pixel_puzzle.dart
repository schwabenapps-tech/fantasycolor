import 'package:flutter/material.dart';

/// Schwierigkeit für Malen-nach-Zahlen (Pixel).
enum PixelDifficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
        PixelDifficulty.easy => 'Leicht',
        PixelDifficulty.medium => 'Mittel',
        PixelDifficulty.hard => 'Schwer',
      };

  /// Zielbreite des Rasters in Zellen (Querformat).
  int get targetCols => maxSide;

  /// Längere Seite des Rasters — gesamtes Bild proportional hinein.
  /// Feiner = Motiv bleibt erkennbar (No.Pix-ähnlich).
  int get maxSide => switch (this) {
        PixelDifficulty.easy => 40,
        PixelDifficulty.medium => 56,
        PixelDifficulty.hard => 72,
      };

  int get colorCount => switch (this) {
        PixelDifficulty.easy => 12,
        PixelDifficulty.medium => 16,
        PixelDifficulty.hard => 22,
      };

  String get hint => switch (this) {
        PixelDifficulty.easy => 'Erkennbares Motiv · ~40 Pixel',
        PixelDifficulty.medium => 'Feinere Pixel · mehr Farben',
        PixelDifficulty.hard => 'Sehr fein · detailreich',
      };
}

/// Eine Farbe in der Malen-nach-Zahlen-Palette (Nummer 1…n).
class PixelPaletteColor {
  const PixelPaletteColor({
    required this.number,
    required this.color,
  });

  final int number;
  final Color color;
}

/// Quantisiertes Pixel-Puzzle: Raster aus Farbindizes + Palette.
class PixelPuzzle {
  const PixelPuzzle({
    required this.cols,
    required this.rows,
    required this.cells,
    required this.palette,
    required this.difficulty,
  });

  final int cols;
  final int rows;

  /// Länge = cols * rows. Wert = Palette-Index (0-basiert).
  final List<int> cells;

  final List<PixelPaletteColor> palette;
  final PixelDifficulty difficulty;

  int indexAt(int x, int y) => cells[y * cols + x];

  int get totalCells => cells.length;

  /// Anzahl Zellen mit dieser Palette-Nummer (1-basiert).
  int countForNumber(int number) {
    final idx = number - 1;
    var n = 0;
    for (final c in cells) {
      if (c == idx) n++;
    }
    return n;
  }
}
