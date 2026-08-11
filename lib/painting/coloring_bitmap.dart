import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../data/paint_catalog.dart';

/// PNG-Ausmalbild mit Flood-Fill auf hellen Flächen (Linien bleiben).
class ColoringBitmap {
  ColoringBitmap._({
    required this.width,
    required this.height,
    required this.original,
    required this.working,
  });

  final int width;
  final int height;

  /// Unveränderte Vorlage (für Radierer / Linien-Erkennung).
  final img.Image original;

  /// Aktuell sichtbares, ausgemaltes Bild.
  img.Image working;

  /// Pixel unter diesem Helligkeitswert gelten als Kontur.
  static const double lineLuminanceMax = 145;

  static Future<ColoringBitmap> load(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('PNG konnte nicht geladen werden: $assetPath');
    }
    final rgba = decoded.convert(numChannels: 4);
    return ColoringBitmap._(
      width: rgba.width,
      height: rgba.height,
      original: img.Image.from(rgba),
      working: img.Image.from(rgba),
    );
  }

  Uint8List snapshot() =>
      Uint8List.fromList(working.getBytes(order: img.ChannelOrder.rgba));

  void restoreSnapshot(Uint8List bytes) {
    working = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: ByteData.sublistView(bytes).buffer,
      bytesOffset: bytes.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  bool isLinePixel(img.Image source, int x, int y) {
    final p = source.getPixel(x, y);
    final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    return lum <= lineLuminanceMax;
  }

  /// Füllt die zusammenhängende helle Region um (x,y).
  int floodFill(
    int x,
    int y, {
    required ui.Color color,
    required PaintCategory category,
    bool erase = false,
  }) {
    if (x < 0 || y < 0 || x >= width || y >= height) return 0;
    if (isLinePixel(original, x, y)) return 0;

    final targetR = color.r * 255.0;
    final targetG = color.g * 255.0;
    final targetB = color.b * 255.0;

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
      if (origLum <= lineLuminanceMax) continue;

      if (erase) {
        working.setPixelRgba(
          cx,
          cy,
          orig.r.toInt(),
          orig.g.toInt(),
          orig.b.toInt(),
          orig.a.toInt(),
        );
      } else {
        final fill = _fillColorFor(
          category: category,
          baseR: targetR,
          baseG: targetG,
          baseB: targetB,
        );
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

    if (!erase && category == PaintCategory.glitter && filled.isNotEmpty) {
      _sprinkleGlitter(filled, color);
    }
    if (!erase && category == PaintCategory.glow && filled.isNotEmpty) {
      _applyGlowBloom(filled, color);
    }

    return count;
  }

  (int, int, int) _fillColorFor({
    required PaintCategory category,
    required double baseR,
    required double baseG,
    required double baseB,
  }) {
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
        r = math.min(255, r * 1.25 + 35);
        g = math.min(255, g * 1.25 + 35);
        b = math.min(255, b * 1.25 + 35);
      case PaintCategory.glitter:
      case PaintCategory.solid:
        break;
    }

    return (
      r.round().clamp(0, 255),
      g.round().clamp(0, 255),
      b.round().clamp(0, 255),
    );
  }

  /// Weicher Leuchtrand um Glow-Füllungen (sichtbarer Glow auf PNG).
  void _applyGlowBloom(List<int> filledIndices, ui.Color base) {
    final filledSet = filledIndices.toSet();
    final glowR = math.min(255, (base.r * 255 * 1.35 + 50).round());
    final glowG = math.min(255, (base.g * 255 * 1.35 + 50).round());
    final glowB = math.min(255, (base.b * 255 * 1.35 + 50).round());
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
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final nidx = ny * width + nx;
          if (filledSet.contains(nidx)) continue;
          if (isLinePixel(original, nx, ny)) continue;
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

    // Kern noch etwas aufhellen für „leuchtendes“ Inneres.
    for (final idx in filledIndices) {
      final x = idx % width;
      final y = idx ~/ width;
      final cur = working.getPixel(x, y);
      working.setPixelRgba(
        x,
        y,
        math.min(255, (cur.r * 1.08 + 12).round()),
        math.min(255, (cur.g * 1.08 + 12).round()),
        math.min(255, (cur.b * 1.08 + 12).round()),
        255,
      );
    }
  }
  void _sprinkleGlitter(List<int> filledIndices, ui.Color base) {
    final random = math.Random(filledIndices.length ^ base.toARGB32());
    final sparkleCount =
        math.min(140, math.max(24, filledIndices.length ~/ 70));
    for (var i = 0; i < sparkleCount; i++) {
      final idx = filledIndices[random.nextInt(filledIndices.length)];
      final x = idx % width;
      final y = idx ~/ width;
      if (isLinePixel(original, x, y)) continue;
      final bright = random.nextDouble() > 0.35;
      final r = bright ? 255 : math.min(255, (base.r * 255 + 90).round());
      final g = bright ? 255 : math.min(255, (base.g * 255 + 90).round());
      final b = bright ? 255 : math.min(255, (base.b * 255 + 50).round());
      working.setPixelRgba(x, y, r, g, b, 255);
      if (x > 0 && !isLinePixel(original, x - 1, y)) {
        working.setPixelRgba(x - 1, y, 255, 255, 255, 255);
      }
      if (x + 1 < width && !isLinePixel(original, x + 1, y)) {
        working.setPixelRgba(x + 1, y, 255, 255, 255, 255);
      }
      if (y > 0 && !isLinePixel(original, x, y - 1)) {
        working.setPixelRgba(x, y - 1, 255, 255, 255, 255);
      }
      if (y + 1 < height && !isLinePixel(original, x, y + 1)) {
        working.setPixelRgba(x, y + 1, 255, 255, 255, 255);
      }
    }
  }

  Future<ui.Image> toUiImage() {
    final bytes =
        Uint8List.fromList(working.getBytes(order: img.ChannelOrder.rgba));
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
