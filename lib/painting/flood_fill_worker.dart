import 'dart:math' as math;

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
    case PaintCategory.watercolor:
      r = r * 0.72 + 255 * 0.28;
      g = g * 0.72 + 255 * 0.28;
      b = b * 0.72 + 255 * 0.28;
    case PaintCategory.glow:
      r = r * 1.25 + 35;
      g = g * 1.25 + 35;
      b = b * 1.25 + 35;
      if (r > 255) r = 255;
      if (g > 255) g = 255;
      if (b > 255) b = 255;
    case PaintCategory.glitter:
      r = r * 1.08 + 18;
      g = g * 1.08 + 18;
      b = b * 1.05 + 12;
      if (r > 255) r = 255;
      if (g > 255) g = 255;
      if (b > 255) b = 255;
    case PaintCategory.solid:
      break;
  }

  return (
    r.round().clamp(0, 255),
    g.round().clamp(0, 255),
    b.round().clamp(0, 255),
  );
}

void _applyGlowBloom(
  img.Image working,
  img.Image original,
  List<int> filledIndices,
  int glowR,
  int glowG,
  int glowB,
  int width,
) {
  final filledSet = filledIndices.toSet();
  final ring = <int>{};

  for (final idx in filledIndices) {
    final x = idx % width;
    final y = idx ~/ width;
    for (var dy = -4; dy <= 4; dy++) {
      for (var dx = -4; dx <= 4; dx++) {
        if (dx == 0 && dy == 0) continue;
        final dist2 = dx * dx + dy * dy;
        if (dist2 > 16) continue;
        final nx = x + dx;
        final ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= working.height) continue;
        final nidx = ny * width + nx;
        if (filledSet.contains(nidx)) continue;
        if (_isLinePixel(original, nx, ny)) continue;
        ring.add(nidx);
      }
    }
  }

  for (final idx in ring) {
    final x = idx % width;
    final y = idx ~/ width;
    final cur = working.getPixel(x, y);
    working.setPixelRgba(
      x,
      y,
      (cur.r * 0.45 + glowR * 0.55).round().clamp(0, 255),
      (cur.g * 0.45 + glowG * 0.55).round().clamp(0, 255),
      (cur.b * 0.45 + glowB * 0.55).round().clamp(0, 255),
      255,
    );
  }

  for (final idx in filledIndices) {
    final x = idx % width;
    final y = idx ~/ width;
    final cur = working.getPixel(x, y);
    working.setPixelRgba(
      x,
      y,
      (cur.r * 1.08 + 12).round().clamp(0, 255),
      (cur.g * 1.08 + 12).round().clamp(0, 255),
      (cur.b * 1.08 + 12).round().clamp(0, 255),
      255,
    );
  }
}

void _sprinkleGlitter(
  img.Image working,
  img.Image original,
  List<int> filledIndices,
  int baseR,
  int baseG,
  int baseB,
  int width,
  int height,
  int colorArgb,
) {
  final filledSet = filledIndices.toSet();
  final random = math.Random(filledIndices.length ^ colorArgb);
  final area = filledIndices.length;
  final density = math.max(18, (math.min(width, height) / 28).round());
  final sparkleCount = math.min(520, math.max(48, area ~/ density));
  final shortSide = math.min(width, height);
  final maxRadius = math.max(2, (shortSide * 0.007).round());

  void putPixel(int x, int y, int r, int g, int b) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final idx = y * width + x;
    if (!filledSet.contains(idx)) return;
    if (_isLinePixel(original, x, y)) return;
    working.setPixelRgba(x, y, r, g, b, 255);
  }

  for (var i = 0; i < sparkleCount; i++) {
    final idx = filledIndices[random.nextInt(filledIndices.length)];
    final cx = idx % width;
    final cy = idx ~/ width;
    if (_isLinePixel(original, cx, cy)) continue;

    final kind = random.nextDouble();
    final radius = math.max(1, 1 + random.nextInt(maxRadius));

    late final int r, g, b;
    if (kind < 0.45) {
      r = 255;
      g = 255;
      b = 255;
    } else if (kind < 0.75) {
      r = math.min(255, baseR + 110);
      g = math.min(255, baseG + 110);
      b = math.min(255, baseB + 90);
    } else {
      r = 255;
      g = 230 + random.nextInt(26);
      b = 140 + random.nextInt(60);
    }

    for (var d = -radius; d <= radius; d++) {
      putPixel(cx + d, cy, r, g, b);
      putPixel(cx, cy + d, r, g, b);
    }

    if (radius >= 2 && random.nextDouble() > 0.4) {
      final diag = math.max(1, radius - 1);
      for (var d = -diag; d <= diag; d++) {
        putPixel(cx + d, cy + d, r, g, b);
        putPixel(cx + d, cy - d, r, g, b);
      }
    }

    putPixel(cx, cy, 255, 255, 255);
  }

  final dustCount = math.min(280, math.max(30, area ~/ (density * 2)));
  for (var i = 0; i < dustCount; i++) {
    final idx = filledIndices[random.nextInt(filledIndices.length)];
    final x = idx % width;
    final y = idx ~/ width;
    if (_isLinePixel(original, x, y)) continue;
    if (random.nextDouble() > 0.5) {
      putPixel(
        x,
        y,
        math.min(255, baseR + 80),
        math.min(255, baseG + 80),
        math.min(255, baseB + 60),
      );
    } else {
      putPixel(x, y, 255, 255, 255);
    }
  }
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
  final filled = <int>[];
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

    filled.add(idx);
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

  if (!request.erase && category == PaintCategory.glitter && filled.isNotEmpty) {
    _sprinkleGlitter(
      working,
      original,
      filled,
      targetR.round().clamp(0, 255),
      targetG.round().clamp(0, 255),
      targetB.round().clamp(0, 255),
      width,
      height,
      colorArgb,
    );
  }
  if (!request.erase && category == PaintCategory.glow && filled.isNotEmpty) {
    final glowR = (targetR * 1.35 + 50).round().clamp(0, 255);
    final glowG = (targetG * 1.35 + 50).round().clamp(0, 255);
    final glowB = (targetB * 1.35 + 50).round().clamp(0, 255);
    _applyGlowBloom(working, original, filled, glowR, glowG, glowB, width);
  }

  final outBytes =
      Uint8List.fromList(working.getBytes(order: img.ChannelOrder.rgba));
  return FloodFillResult(changed: count, workingBytes: outBytes);
}

Future<FloodFillResult> runFloodFill(FloodFillRequest request) {
  return compute(floodFillWorker, request);
}
