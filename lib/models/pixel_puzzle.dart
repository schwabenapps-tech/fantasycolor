import 'package:flutter/material.dart';

/// Pixel-/Malen-nach-Zahlen — ein Modus, der das Motiv möglichst erkennbar hält.
///
/// Ältere Saves können noch `easy`/`medium`/`hard` speichern; beim Laden
/// werden sie auf [standard] gemappt. Raster/Zellen kommen aus dem Snapshot.
enum PixelDifficulty {
  standard;

  /// Feines Raster: längere Seite — Motiv bleibt gut erkennbar.
  int get maxSide => 96;

  int get colorCount => 20;

  /// Für Fortschritts-JSON und alte Speichernamen (`easy`/`medium`/`hard`).
  static PixelDifficulty fromStorageName(String? _) =>
      PixelDifficulty.standard;
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
