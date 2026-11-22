import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/pixel_puzzle.dart';
import '../utils/image_source.dart';

/// Erzeugt ein Malen-nach-Zahlen-Raster aus dem **gesamten** Asset-Bild.
///
/// Pro Zelle: dominante Farbe aus dem Original (flach/genau für Ausmalen).
/// Ähnliche Farben werden aggressiv zur häufigeren Farbe gemappt — ohne
/// Mittelwert, damit Rottöne nicht „doppelt“ in der Palette landen.
class PixelQuantizer {
  PixelQuantizer._();

  /// Algo-Stand — bei Änderung Pixel-Saves invalidieren.
  static const algoVersion = 3;

  /// CIE76 ΔE — darunter gilt „gleiche Farbe“ für die Palette.
  static const mergeDeltaE = 22.0;

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
  final maxSide = args.maxSide.clamp(24, 128);
  late final int cols;
  late final int rows;
  if (src.width >= src.height) {
    cols = maxSide;
    rows = math.max(8, (maxSide * src.height / src.width).round());
  } else {
    rows = maxSide;
    cols = math.max(8, (maxSide * src.width / src.height).round());
  }

  // Pro Rasterzelle dominante Farbe aus dem Original → Motiv bleibt treu.
  final cellArgb = List<int>.filled(cols * rows, 0xFFFFFFFF);
  for (var cy = 0; cy < rows; cy++) {
    final y0 = (cy * src.height / rows).floor();
    final y1 = (((cy + 1) * src.height / rows).ceil()).clamp(y0 + 1, src.height);
    for (var cx = 0; cx < cols; cx++) {
      final x0 = (cx * src.width / cols).floor();
      final x1 =
          (((cx + 1) * src.width / cols).ceil()).clamp(x0 + 1, src.width);
      cellArgb[cy * cols + cx] = _dominantArgb(src, x0, y0, x1, y1);
    }
  }

  // Häufigste exakte Zellenfarben → Palette (Winner behält RGB).
  final freq = <int, int>{};
  for (final c in cellArgb) {
    freq[c] = (freq[c] ?? 0) + 1;
  }
  final ranked = freq.keys.toList(growable: false)
    ..sort((a, b) => freq[b]!.compareTo(freq[a]!));

  final paletteArgb = <int>[];
  final keyToPalette = <int, int>{};
  final maxColors = args.colorCount.clamp(4, 32);

  for (final key in ranked) {
    final lab = _rgbToLab(key);
    var best = -1;
    var bestD = args.mergeDeltaE;
    for (var i = 0; i < paletteArgb.length; i++) {
      final d = _paletteDistance(lab, _rgbToLab(paletteArgb[i]), key, paletteArgb[i]);
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
      // Limit erreicht → nächstgelegene Palette-Farbe.
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

  // Nach Häufigkeit sortieren → Nummer 1 = dominante Farbe.
  final order = List<int>.generate(paletteArgb.length, (i) => i)
    ..sort((a, b) => counts[b].compareTo(counts[a]));

  final remap = List<int>.filled(paletteArgb.length, 0);
  for (var newIdx = 0; newIdx < order.length; newIdx++) {
    remap[order[newIdx]] = newIdx;
  }
  for (var i = 0; i < cells.length; i++) {
    cells[i] = remap[cells[i]];
  }

  return _QuantizeResult(
    cols: cols,
    rows: rows,
    cells: cells,
    paletteArgb: [for (final oi in order) paletteArgb[oi]],
  );
}

/// Häufigste Farbe im Block (leicht gerastert gegen Anti-Alias-Rauschen).
int _dominantArgb(img.Image src, int x0, int y0, int x1, int y1) {
  final hist = <int, int>{};
  // Schrittweite: große Zellen nicht pixelweise — trotzdem repräsentativ.
  final stepX = math.max(1, (x1 - x0) ~/ 12);
  final stepY = math.max(1, (y1 - y0) ~/ 12);
  for (var y = y0; y < y1; y += stepY) {
    for (var x = x0; x < x1; x += stepX) {
      final p = src.getPixel(x, y);
      // 5-Bit-Buckets: Kantenglätten fällt zusammen, klare Swatches bleiben.
      final r = (p.r.toInt() >> 3) << 3;
      final g = (p.g.toInt() >> 3) << 3;
      final b = (p.b.toInt() >> 3) << 3;
      final key = 0xFF000000 | (r << 16) | (g << 8) | b;
      hist[key] = (hist[key] ?? 0) + 1;
    }
  }
  if (hist.isEmpty) return 0xFFFFFFFF;
  var bestKey = hist.keys.first;
  var bestN = 0;
  for (final e in hist.entries) {
    if (e.value > bestN) {
      bestN = e.value;
      bestKey = e.key;
    }
  }
  return bestKey;
}

/// Distanz: CIE76 + Extra-Druck für gleiche Buntheit/ähnlichen Hue (Rottöne).
double _paletteDistance(
  (double, double, double) a,
  (double, double, double) b,
  int argbA,
  int argbB,
) {
  final de = _deltaE(a, b);
  final ha = _hueChroma(argbA);
  final hb = _hueChroma(argbB);
  // Beide bunt und ähnlicher Farbton → stärker zusammenziehen.
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
