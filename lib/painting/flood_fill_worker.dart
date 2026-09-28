import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../data/paint_catalog.dart';
import 'flood_fill_tuning.dart';

/// Parameter für Flood-Fill im Hintergrund-Isolate.
class FloodFillRequest {
  const FloodFillRequest({
    required this.workingBytes,
    required this.originalBytes,
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    required this.colorArgb,
    required this.categoryIndex,
    required this.erase,
    this.tuning = FloodFillTuning.standard,
  });

  final Uint8List workingBytes;
  final Uint8List originalBytes;
  final int width;
  final int height;
  final int x;
  final int y;
  final int colorArgb;
  final int categoryIndex;
  final bool erase;
  final FloodFillTuning tuning;
}

class FloodFillResult {
  const FloodFillResult({
    required this.changed,
    required this.workingBytes,
  });

  final int changed;
  final Uint8List workingBytes;
}

double _luminance(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

(int, int, int) _fillColorFor(
  PaintCategory category,
  double baseR,
  double baseG,
  double baseB,
) {
  var r = baseR;
  var g = baseG;
  var b = baseB;

  switch (category) {
    case PaintCategory.pastel:
      r = r + (255 - r) * 0.22;
      g = g + (255 - g) * 0.22;
      b = b + (255 - b) * 0.22;
    case PaintCategory.solid:
      break;
  }

  return (
    r.round().clamp(0, 255),
    g.round().clamp(0, 255),
    b.round().clamp(0, 255),
  );
}

void _paintPixel({
  required img.Image working,
  required img.Image original,
  required int x,
  required int y,
  required bool erase,
  required PaintCategory category,
  required double targetR,
  required double targetG,
  required double targetB,
}) {
  final orig = original.getPixel(x, y);
  if (erase) {
    working.setPixelRgba(
      x,
      y,
      orig.r.toInt(),
      orig.g.toInt(),
      orig.b.toInt(),
      orig.a.toInt(),
    );
  } else {
    final fill = _fillColorFor(category, targetR, targetG, targetB);
    working.setPixelRgba(x, y, fill.$1, fill.$2, fill.$3, 255);
  }
}

FloodFillResult floodFillWorker(FloodFillRequest request) {
  final tuning = request.tuning;
  final original = img.Image.fromBytes(
    width: request.width,
    height: request.height,
    bytes: request.originalBytes.buffer,
    bytesOffset: request.originalBytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  final working = img.Image.fromBytes(
    width: request.width,
    height: request.height,
    bytes: request.workingBytes.buffer,
    bytesOffset: request.workingBytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  final x = request.x;
  final y = request.y;
  final width = request.width;
  final height = request.height;

  if (x < 0 || y < 0 || x >= width || y >= height) {
    return FloodFillResult(changed: 0, workingBytes: request.workingBytes);
  }
  if (_luminance(original.getPixel(x, y)) < tuning.fillRegionLuminanceMin) {
    return FloodFillResult(changed: 0, workingBytes: request.workingBytes);
  }

  final category = PaintCategory.values[request.categoryIndex];
  final colorArgb = request.colorArgb;
  final a = (colorArgb >> 24) & 0xFF;
  final targetR = ((colorArgb >> 16) & 0xFF) * (a / 255.0);
  final targetG = ((colorArgb >> 8) & 0xFF) * (a / 255.0);
  final targetB = (colorArgb & 0xFF) * (a / 255.0);

  final painted = Uint8List(width * height);
  final stackX = <int>[x];
  final stackY = <int>[y];
  var count = 0;

  while (stackX.isNotEmpty) {
    final cx = stackX.removeLast();
    final cy = stackY.removeLast();
    if (cx < 0 || cy < 0 || cx >= width || cy >= height) continue;
    final idx = cy * width + cx;
    if (painted[idx] == 1) continue;

    final origLum = _luminance(original.getPixel(cx, cy));
    if (origLum < tuning.fillRegionLuminanceMin) continue;

    painted[idx] = 1;
    _paintPixel(
      working: working,
      original: original,
      x: cx,
      y: cy,
      erase: request.erase,
      category: category,
      targetR: targetR,
      targetG: targetG,
      targetB: targetB,
    );
    count++;

    stackX
      ..add(cx - 1)
      ..add(cx + 1)
      ..add(cx)
      ..add(cx);
    stackY
      ..add(cy)
      ..add(cy)
      ..add(cy - 1)
      ..add(cy + 1);
  }

  final neighborDeltas = tuning.fringeDiagonals
      ? const <(int, int)>[
          (-1, -1),
          (0, -1),
          (1, -1),
          (-1, 0),
          (1, 0),
          (-1, 1),
          (0, 1),
          (1, 1),
        ]
      : const <(int, int)>[
          (0, -1),
          (-1, 0),
          (1, 0),
          (0, 1),
        ];

  for (var pass = 0; pass < tuning.fringeExpandPasses; pass++) {
    final frontier = <int>[
      for (var i = 0; i < painted.length; i++)
        if (painted[i] == 1) i,
    ];
    var grew = 0;
    for (final i in frontier) {
      final cx = i % width;
      final cy = i ~/ width;
      for (final (dx, dy) in neighborDeltas) {
        final nx = cx + dx;
        final ny = cy + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        final nIdx = ny * width + nx;
        if (painted[nIdx] == 1) continue;
        final lum = _luminance(original.getPixel(nx, ny));
        // Nur helle Anti-Alias-Fransen — nicht durch dünne Graulinien.
        if (lum <= tuning.hardLineLuminanceMax) continue;
        if (lum < tuning.fringeLuminanceMin) continue;
        painted[nIdx] = 1;
        _paintPixel(
          working: working,
          original: original,
          x: nx,
          y: ny,
          erase: request.erase,
          category: category,
          targetR: targetR,
          targetG: targetG,
          targetB: targetB,
        );
        count++;
        grew++;
      }
    }
    if (grew == 0) break;
  }

  final outBytes =
      Uint8List.fromList(working.getBytes(order: img.ChannelOrder.rgba));
  return FloodFillResult(changed: count, workingBytes: outBytes);
}

Future<FloodFillResult> runFloodFill(FloodFillRequest request) {
  return compute(floodFillWorker, request);
}
