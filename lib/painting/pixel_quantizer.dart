import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/pixel_puzzle.dart';

/// Erzeugt ein Malen-nach-Zahlen-Raster aus dem **gesamten** Asset-Bild.
///
/// Kein Zuschnitt: das volle Bild wird proportional verkleinert (längere Seite
/// = Schwierigkeit), Seitenverhältnis bleibt erhalten.
class PixelQuantizer {
  PixelQuantizer._();

  static Future<PixelPuzzle> fromAsset(
    String assetPath, {
    required PixelDifficulty difficulty,
  }) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final raw = await compute(
      _quantizeIsolate,
      _QuantizeArgs(
        bytes: bytes,
        maxSide: difficulty.maxSide,
        colorCount: difficulty.colorCount,
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
  });

  final Uint8List bytes;
  final int maxSide;
  final int colorCount;
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
    throw StateError('Bild konnte nicht geladen werden');
  }

  final src = decoded.convert(numChannels: 4);

  // Gesamtes Bild in maxSide×maxSide-Box, Aspekt beibehalten — kein Crop.
  final maxSide = args.maxSide.clamp(16, 96);
  late final int cols;
  late final int rows;
  if (src.width >= src.height) {
    cols = maxSide;
    rows = math.max(8, (maxSide * src.height / src.width).round());
  } else {
    rows = maxSide;
    cols = math.max(8, (maxSide * src.width / src.height).round());
  }

  final resized = img.copyResize(
    src,
    width: cols,
    height: rows,
    interpolation: img.Interpolation.average,
  );

  final colorCount = args.colorCount.clamp(4, 28);
  final quantized = img.quantize(
    resized,
    numberOfColors: colorCount,
    method: img.QuantizeMethod.neuralNet,
    dither: img.DitherKernel.none,
  );

  final colorKeys = <int>[];
  final keyToIndex = <int, int>{};
  final cells = List<int>.filled(cols * rows, 0);

  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final p = quantized.getPixel(x, y);
      final key = (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
      var idx = keyToIndex[key];
      if (idx == null) {
        idx = colorKeys.length;
        keyToIndex[key] = idx;
        colorKeys.add(key);
      }
      cells[y * cols + x] = idx;
    }
  }

  final clusterCount = colorKeys.length;
  final counts = List<int>.filled(clusterCount, 0);
  final sumR = List<double>.filled(clusterCount, 0);
  final sumG = List<double>.filled(clusterCount, 0);
  final sumB = List<double>.filled(clusterCount, 0);

  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final idx = cells[y * cols + x];
      final p = resized.getPixel(x, y);
      sumR[idx] += p.r;
      sumG[idx] += p.g;
      sumB[idx] += p.b;
      counts[idx]++;
    }
  }

  final order = List<int>.generate(clusterCount, (i) => i)
    ..sort((a, b) => counts[b].compareTo(counts[a]));

  final remap = List<int>.filled(clusterCount, 0);
  for (var newIdx = 0; newIdx < order.length; newIdx++) {
    remap[order[newIdx]] = newIdx;
  }
  for (var i = 0; i < cells.length; i++) {
    cells[i] = remap[cells[i]];
  }

  final paletteArgb = <int>[];
  for (final oi in order) {
    final n = counts[oi].clamp(1, 1 << 30);
    final r = (sumR[oi] / n).round().clamp(0, 255);
    final g = (sumG[oi] / n).round().clamp(0, 255);
    final b = (sumB[oi] / n).round().clamp(0, 255);
    paletteArgb.add(0xFF000000 | (r << 16) | (g << 8) | b);
  }

  return _QuantizeResult(
    cols: cols,
    rows: rows,
    cells: cells,
    paletteArgb: paletteArgb,
  );
}
