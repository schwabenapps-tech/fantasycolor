import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/pixel_puzzle.dart';
import '../utils/image_source.dart';

/// Erzeugt ein Malen-nach-Zahlen-Raster aus dem **gesamten** Asset-Bild.
///
/// Pro Zelle: Füllfarbe ohne Linien-AA, oder Kontur wenn genug dunkle Linie
/// in der Zelle / im Zentrum liegt — damit Motivlinien sauber bleiben.
class PixelQuantizer {
  PixelQuantizer._();

  /// Algo-Stand — bei Änderung Pixel-Saves invalidieren.
  static const algoVersion = 8;

  /// CIE76 ΔE — darunter gilt „gleiche Farbe“ für die Palette.
  /// Kleiner = mehr Farbnuancen bleiben erhalten.
  static const mergeDeltaE = 11.0;

  static const lineArgb = 0xFF1A1A1A;

  static Future<PixelPuzzle> fromAsset(
    String assetPath, {
    required PixelDifficulty difficulty,
  }) async {
    final bytes = await loadImageBytes(assetPath);
    return fromBytes(bytes, difficulty: difficulty);
  }

  /// Quantisiert fertiges Ausmal-PNG (oder beliebiges Bild).
  static Future<PixelPuzzle> fromBytes(
    Uint8List bytes, {
    required PixelDifficulty difficulty,
  }) async {
    final raw = await compute(
      _quantizeIsolate,
      _QuantizeArgs(
        bytes: bytes,
        maxSide: difficulty.maxSide,
        colorCount: difficulty.colorCount,
        mergeDeltaE: mergeDeltaE,
      ),
    );

    final palette = <PixelPaletteColor>[
      for (var i = 0; i < raw.paletteArgb.length; i++)
        PixelPaletteColor(
          number: i + 1,
          color: Color(raw.paletteArgb[i]),
        ),
    ];

    return PixelPuzzle(
      cols: raw.cols,
      rows: raw.rows,
      cells: raw.cells,
      palette: palette,
      difficulty: difficulty,
    );
  }
}

class _QuantizeArgs {
  const _QuantizeArgs({
    required this.bytes,
    required this.maxSide,
    required this.colorCount,
    required this.mergeDeltaE,
  });

  final Uint8List bytes;
  final int maxSide;
  final int colorCount;
  final double mergeDeltaE;
}

class _QuantizeResult {
  const _QuantizeResult({
    required this.cols,
    required this.rows,
    required this.cells,
    required this.paletteArgb,
  });

  final int cols;
  final int rows;
  final List<int> cells;
  final List<int> paletteArgb;
}

_QuantizeResult _quantizeIsolate(_QuantizeArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) {
    throw StateError('Could not load image');
  }

  final src = decoded.convert(numChannels: 4);
  final maxSide = args.maxSide.clamp(24, 256);
  late final int cols;
  late final int rows;
  if (src.width >= src.height) {
    cols = maxSide;
    rows = math.max(8, (maxSide * src.height / src.width).round());
  } else {
    rows = maxSide;
    cols = math.max(8, (maxSide * src.width / src.height).round());
  }

  final cellArgb = List<int>.filled(cols * rows, 0xFFFFFFFF);
  final lineHint = List<double>.filled(cols * rows, 0);

  for (var cy = 0; cy < rows; cy++) {
    final y0 = (cy * src.height / rows).floor();
    final y1 = (((cy + 1) * src.height / rows).ceil()).clamp(y0 + 1, src.height);
    for (var cx = 0; cx < cols; cx++) {
      final x0 = (cx * src.width / cols).floor();
      final x1 =
          (((cx + 1) * src.width / cols).ceil()).clamp(x0 + 1, src.width);
      final sample = _sampleCell(src, x0, y0, x1, y1);
      cellArgb[cy * cols + cx] = sample.argb;
      lineHint[cy * cols + cx] = sample.lineRatio;
    }
  }

  // Dünne Linien verbinden: Zelle mit etwas Linie zwischen Linien-Nachbarn.
  _restoreLineContinuity(cellArgb, lineHint, cols, rows);
  // Einzelne Fehl-Dots glätten — ruhigere Flächen für Dot Art.
  _despeckleCellArgb(cellArgb, cols, rows);

  // Häufigste exakte Zellenfarben → Palette (Winner behält RGB).
  final freq = <int, int>{};
  for (final c in cellArgb) {
    freq[c] = (freq[c] ?? 0) + 1;
  }
  final ranked = freq.keys.toList(growable: false)
    ..sort((a, b) => freq[b]!.compareTo(freq[a]!));

  // Linie zuerst in die Palette, damit sie nicht „weggemerged“ wird.
  final paletteArgb = <int>[];
  final keyToPalette = <int, int>{};
  final maxColors = args.colorCount.clamp(4, 40);

  if (freq.containsKey(PixelQuantizer.lineArgb)) {
    keyToPalette[PixelQuantizer.lineArgb] = 0;
    paletteArgb.add(PixelQuantizer.lineArgb);
  }

  for (final key in ranked) {
    if (keyToPalette.containsKey(key)) continue;
    final lab = _rgbToLab(key);
    var best = -1;
    var bestD = args.mergeDeltaE;
    for (var i = 0; i < paletteArgb.length; i++) {
      final d = _paletteDistance(
        lab,
        _rgbToLab(paletteArgb[i]),
        key,
        paletteArgb[i],
      );
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best >= 0) {
      keyToPalette[key] = best;
    } else if (paletteArgb.length < maxColors) {
      keyToPalette[key] = paletteArgb.length;
      paletteArgb.add(key);
    } else {
      var nearest = 0;
      var nearestD = double.infinity;
      for (var i = 0; i < paletteArgb.length; i++) {
        final d = _paletteDistance(
          lab,
          _rgbToLab(paletteArgb[i]),
          key,
          paletteArgb[i],
        );
        if (d < nearestD) {
          nearestD = d;
          nearest = i;
        }
      }
      keyToPalette[key] = nearest;
    }
  }

  final cells = List<int>.filled(cols * rows, 0);
  final counts = List<int>.filled(paletteArgb.length, 0);
  for (var i = 0; i < cellArgb.length; i++) {
    final idx = keyToPalette[cellArgb[i]]!;
    cells[i] = idx;
    counts[idx]++;
  }

  final order = List<int>.generate(paletteArgb.length, (i) => i)
    ..sort((a, b) => counts[b].compareTo(counts[a]));

  final remap = List<int>.filled(paletteArgb.length, 0);
  for (var newIdx = 0; newIdx < order.length; newIdx++) {
    remap[order[newIdx]] = newIdx;
  }
  for (var i = 0; i < cells.length; i++) {
    cells[i] = remap[cells[i]];
  }

  final orderedPalette = [for (final oi in order) paletteArgb[oi]];
  _despecklePaletteCells(cells, orderedPalette, cols, rows);

  return _QuantizeResult(
    cols: cols,
    rows: rows,
    cells: cells,
    paletteArgb: orderedPalette,
  );
}

class _CellSample {
  const _CellSample({required this.argb, required this.lineRatio});
  final int argb;
  final double lineRatio;
}

_CellSample _sampleCell(img.Image src, int x0, int y0, int x1, int y1) {
  final fillHist = <int, int>{};
  final sumR = <int, int>{};
  final sumG = <int, int>{};
  final sumB = <int, int>{};
  var lineN = 0;
  var fillN = 0;
  var centerLine = 0;
  var centerTotal = 0;

  final w = x1 - x0;
  final h = y1 - y0;
  // Sehr dicht sampeln → genaue Dot-Farben aus fertigen Ausmalbildern.
  final stepX = math.max(1, w ~/ 48);
  final stepY = math.max(1, h ~/ 48);
  final cx0 = x0 + w ~/ 4;
  final cx1 = x1 - w ~/ 4;
  final cy0 = y0 + h ~/ 4;
  final cy1 = y1 - h ~/ 4;

  for (var y = y0; y < y1; y += stepY) {
    for (var x = x0; x < x1; x += stepX) {
      final p = src.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final inCenter = x >= cx0 && x < cx1 && y >= cy0 && y < cy1;
      if (inCenter) centerTotal++;

      if (_isLineRgb(r, g, b)) {
        lineN++;
        if (inCenter) centerLine++;
        continue;
      }

      fillN++;
      // Feinere Buckets (4er statt 8er) — Motivfarben bleiben klarer.
      final br = (r >> 2) << 2;
      final bg = (g >> 2) << 2;
      final bb = (b >> 2) << 2;
      final key = 0xFF000000 | (br << 16) | (bg << 8) | bb;
      // Zentrum zählt doppelt — mittlere Flächenfarbe gewinnt gegen Rand-AA.
      final weight = inCenter ? 2 : 1;
      fillHist[key] = (fillHist[key] ?? 0) + weight;
      sumR[key] = (sumR[key] ?? 0) + r * weight;
      sumG[key] = (sumG[key] ?? 0) + g * weight;
      sumB[key] = (sumB[key] ?? 0) + b * weight;
    }
  }

  final total = lineN + fillN;
  final lineRatio = total == 0 ? 0.0 : lineN / total;
  final centerRatio =
      centerTotal == 0 ? 0.0 : centerLine / centerTotal;

  if (fillHist.isEmpty) {
    return _CellSample(
      argb: lineRatio > 0.08 ? PixelQuantizer.lineArgb : 0xFFFFFFFF,
      lineRatio: lineRatio,
    );
  }

  var bestKey = fillHist.keys.first;
  var bestN = 0;
  for (final e in fillHist.entries) {
    if (e.value > bestN) {
      bestN = e.value;
      bestKey = e.key;
    }
  }
  // Mittelwert der Samples im Winner-Bucket → natürlichere Dot-Farbe.
  final n = fillHist[bestKey]!;
  final ar = (sumR[bestKey]! / n).round().clamp(0, 255);
  final ag = (sumG[bestKey]! / n).round().clamp(0, 255);
  final ab = (sumB[bestKey]! / n).round().clamp(0, 255);
  final fillArgb = 0xFF000000 | (ar << 16) | (ag << 8) | ab;

  // Füllfarbe hat Vorrang: dunkle Motivfarben nicht als Linie opfern.
  // Nur klar linien-dominante Zellen → Kontur.
  final mostlyLine = lineRatio >= 0.52 || centerRatio >= 0.62;
  final edgeOnlyLine = lineRatio >= 0.38 &&
      centerRatio >= 0.48 &&
      fillN < lineN * 0.45;
  if (mostlyLine || edgeOnlyLine) {
    return _CellSample(argb: PixelQuantizer.lineArgb, lineRatio: lineRatio);
  }

  return _CellSample(argb: fillArgb, lineRatio: lineRatio);
}

/// Entfernt einzelne „Falschfarben“-Zellen zugunsten der Nachbar-Mehrheit.
void _despeckleCellArgb(List<int> cellArgb, int cols, int rows) {
  final line = PixelQuantizer.lineArgb;
  for (var pass = 0; pass < 2; pass++) {
    final next = List<int>.from(cellArgb);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final i = y * cols + x;
        final self = cellArgb[i];
        final hist = <int, int>{};
        var same = 0;
        void tap(int nx, int ny) {
          if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) return;
          final c = cellArgb[ny * cols + nx];
          hist[c] = (hist[c] ?? 0) + 1;
          if (c == self) same++;
        }

        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            tap(x + dx, y + dy);
          }
        }
        if (hist.isEmpty) continue;

        var maj = self;
        var majN = 0;
        for (final e in hist.entries) {
          if (e.value > majN) {
            majN = e.value;
            maj = e.key;
          }
        }

        // Nur echte Einzel-Pixel glätten — Details nicht weichwaschen.
        if (self == line) {
          if (same == 0 && maj != line && majN >= 6) {
            next[i] = maj;
          }
          continue;
        }
        if (same == 0 && maj != self && majN >= 5) {
          next[i] = maj;
        }
      }
    }
    for (var i = 0; i < cellArgb.length; i++) {
      cellArgb[i] = next[i];
    }
  }
}

void _despecklePaletteCells(
  List<int> cells,
  List<int> paletteArgb,
  int cols,
  int rows,
) {
  final lineIdx = paletteArgb.indexWhere((c) => c == PixelQuantizer.lineArgb);
  for (var pass = 0; pass < 1; pass++) {
    final next = List<int>.from(cells);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final i = y * cols + x;
        final self = cells[i];
        if (self == lineIdx) continue;
        final hist = <int, int>{};
        var same = 0;
        void tap(int nx, int ny) {
          if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) return;
          final c = cells[ny * cols + nx];
          hist[c] = (hist[c] ?? 0) + 1;
          if (c == self) same++;
        }

        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            tap(x + dx, y + dy);
          }
        }
        if (same > 0 || hist.isEmpty) continue;
        var maj = self;
        var majN = 0;
        for (final e in hist.entries) {
          if (e.value > majN) {
            majN = e.value;
            maj = e.key;
          }
        }
        if (maj != self && maj != lineIdx && majN >= 5) {
          next[i] = maj;
        }
      }
    }
    for (var i = 0; i < cells.length; i++) {
      cells[i] = next[i];
    }
  }
}

void _restoreLineContinuity(
  List<int> cellArgb,
  List<double> lineHint,
  int cols,
  int rows,
) {
  final line = PixelQuantizer.lineArgb;
  // Mehrere Pässe: Lücken in Linien schließen.
  for (var pass = 0; pass < 2; pass++) {
    final next = List<int>.from(cellArgb);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final i = y * cols + x;
        if (cellArgb[i] == line) continue;
        // Nur echte Lücken schließen — keine farbigen Flächen „auffressen“.
        if (lineHint[i] < 0.14) continue;

        var lineNeighbors = 0;
        void check(int nx, int ny) {
          if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) return;
          if (cellArgb[ny * cols + nx] == line) lineNeighbors++;
        }

        check(x - 1, y);
        check(x + 1, y);
        check(x, y - 1);
        check(x, y + 1);

        // Brücke zwischen gegenüberliegenden Linien.
        final horiz = x > 0 &&
            x < cols - 1 &&
            cellArgb[y * cols + (x - 1)] == line &&
            cellArgb[y * cols + (x + 1)] == line;
        final vert = y > 0 &&
            y < rows - 1 &&
            cellArgb[(y - 1) * cols + x] == line &&
            cellArgb[(y + 1) * cols + x] == line;

        if (horiz || vert || (lineNeighbors >= 3 && lineHint[i] >= 0.22)) {
          next[i] = line;
        }
      }
    }
    for (var i = 0; i < cellArgb.length; i++) {
      cellArgb[i] = next[i];
    }
  }
}

bool _isLineRgb(int r, int g, int b) {
  final lum = 0.299 * r + 0.587 * g + 0.114 * b;
  final chroma = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
  // Nur dunkles Grau/Schwarz = Kontur.
  // Dunkles Blau/Rot/Lila ist Füllfarbe und darf nicht zur Linie werden.
  if (lum <= 48 && chroma <= 40) return true;
  if (lum <= 90 && chroma <= 26) return true;
  if (lum <= 120 && chroma <= 18) return true;
  return false;
}

bool _isLineArgb(int argb) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return argb == PixelQuantizer.lineArgb || _isLineRgb(r, g, b);
}

/// Distanz: CIE76 + Hue-Druck; Linie und Füllfarbe nie zusammenführen.
double _paletteDistance(
  (double, double, double) a,
  (double, double, double) b,
  int argbA,
  int argbB,
) {
  final lineA = _isLineArgb(argbA);
  final lineB = _isLineArgb(argbB);
  if (lineA != lineB) return 999;

  final de = _deltaE(a, b);
  final ha = _hueChroma(argbA);
  final hb = _hueChroma(argbB);
  if (ha.$2 >= 25 && hb.$2 >= 25) {
    final dh = _hueDiff(ha.$1, hb.$1);
    final dl = (a.$1 - b.$1).abs();
    if (dh <= 20 && dl <= 22) {
      return math.min(de, dh * 0.55 + dl * 0.35);
    }
  }
  return de;
}

(double, double) _hueChroma(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255.0;
  final g = ((argb >> 8) & 0xFF) / 255.0;
  final b = (argb & 0xFF) / 255.0;
  final max = math.max(r, math.max(g, b));
  final min = math.min(r, math.min(g, b));
  final c = max - min;
  if (c < 1e-6) return (0.0, 0.0);
  late final double h;
  if (max == r) {
    h = 60 * (((g - b) / c) % 6);
  } else if (max == g) {
    h = 60 * (((b - r) / c) + 2);
  } else {
    h = 60 * (((r - g) / c) + 4);
  }
  final hue = h < 0 ? h + 360 : h;
  return (hue, c * 100);
}

double _hueDiff(double a, double b) {
  final d = (a - b).abs();
  return math.min(d, 360 - d);
}

(double, double, double) _rgbToLab(int argb) {
  var r = ((argb >> 16) & 0xFF) / 255.0;
  var g = ((argb >> 8) & 0xFF) / 255.0;
  var b = (argb & 0xFF) / 255.0;

  double lin(double c) =>
      c > 0.04045 ? math.pow((c + 0.055) / 1.055, 2.4).toDouble() : c / 12.92;
  r = lin(r);
  g = lin(g);
  b = lin(b);

  final x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047;
  final y = (r * 0.2126729 + g * 0.7151522 + b * 0.0721750);
  final z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883;

  double f(double t) => t > 0.008856
      ? math.pow(t, 1 / 3).toDouble()
      : (7.787 * t) + (16 / 116);

  final fx = f(x);
  final fy = f(y);
  final fz = f(z);
  return ((116 * fy) - 16, 500 * (fx - fy), 200 * (fy - fz));
}

double _deltaE((double, double, double) a, (double, double, double) b) {
  final dL = a.$1 - b.$1;
  final da = a.$2 - b.$2;
  final db = a.$3 - b.$3;
  return math.sqrt(dL * dL + da * da + db * db);
}
