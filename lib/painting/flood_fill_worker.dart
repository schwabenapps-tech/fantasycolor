import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../data/paint_catalog.dart';

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
}

class FloodFillResult {
  const FloodFillResult({
    required this.changed,
    required this.workingBytes,
  });

  final int changed;
  final Uint8List workingBytes;
}

const _lineLuminanceMax = 145.0;

bool _isLinePixel(img.Image source, int x, int y) {
  final p = source.getPixel(x, y);
  final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  return lum <= _lineLuminanceMax;
}

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

FloodFillResult floodFillWorker(FloodFillRequest request) {
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
  if (_isLinePixel(original, x, y)) {
    return FloodFillResult(changed: 0, workingBytes: request.workingBytes);
  }

  final category = PaintCategory.values[request.categoryIndex];
  final colorArgb = request.colorArgb;
  final a = (colorArgb >> 24) & 0xFF;
  final targetR = ((colorArgb >> 16) & 0xFF) * (a / 255.0);
  final targetG = ((colorArgb >> 8) & 0xFF) * (a / 255.0);
  final targetB = (colorArgb & 0xFF) * (a / 255.0);

  final visited = Uint8List(width * height);
  final stackX = <int>[x];
  final stackY = <int>[y];
  var count = 0;

  while (stackX.isNotEmpty) {
    final cx = stackX.removeLast();
    final cy = stackY.removeLast();
    if (cx < 0 || cy < 0 || cx >= width || cy >= height) continue;
    final idx = cy * width + cx;
    if (visited[idx] == 1) continue;
    visited[idx] = 1;

    final orig = original.getPixel(cx, cy);
    final origLum = 0.299 * orig.r + 0.587 * orig.g + 0.114 * orig.b;
    if (origLum <= _lineLuminanceMax) continue;

    if (request.erase) {
      working.setPixelRgba(
        cx,
        cy,
        orig.r.toInt(),
        orig.g.toInt(),
        orig.b.toInt(),
        orig.a.toInt(),
      );
    } else {
      final fill = _fillColorFor(category, targetR, targetG, targetB);
      working.setPixelRgba(cx, cy, fill.$1, fill.$2, fill.$3, 255);
    }

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

  final outBytes =
      Uint8List.fromList(working.getBytes(order: img.ChannelOrder.rgba));
  return FloodFillResult(changed: count, workingBytes: outBytes);
}

Future<FloodFillResult> runFloodFill(FloodFillRequest request) {
  return compute(floodFillWorker, request);
}
