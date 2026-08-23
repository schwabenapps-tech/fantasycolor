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

  /// Arbeitsbild auf die unveränderte Vorlage zurücksetzen.
  void resetToOriginal() {
    working = img.Image.from(original);
  }

  /// Gespeicherten PNG-Fortschritt als Arbeitsbild laden.
  bool applyWorkingPng(Uint8List pngBytes) {
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) return false;
    final rgba = decoded.convert(numChannels: 4);
    if (rgba.width != width || rgba.height != height) {
      final resized = img.copyResize(
        rgba,
        width: width,
        height: height,
        interpolation: img.Interpolation.average,
      );
      working = resized.convert(numChannels: 4);
    } else {
      working = rgba;
    }
    return true;
  }

  /// Aktuelles Arbeitsbild als PNG-Bytes.
  Uint8List encodeWorkingPng() =>
      Uint8List.fromList(img.encodePng(working));

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
        // Leichter metallischer Schimmer als Basis.
        r = math.min(255, r * 1.08 + 18);
        g = math.min(255, g * 1.08 + 18);
        b = math.min(255, b * 1.05 + 12);
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
  /// Sichtbarer Glitzer über der gefüllten Fläche (Sterne, Punkte, Schimmer).
  void _sprinkleGlitter(List<int> filledIndices, ui.Color base) {
    final filledSet = filledIndices.toSet();
    final random = math.Random(filledIndices.length ^ base.toARGB32());

    final baseR = (base.r * 255).round().clamp(0, 255);
    final baseG = (base.g * 255).round().clamp(0, 255);
    final baseB = (base.b * 255).round().clamp(0, 255);

    // Dichte an Flächengröße und Bildauflösung koppeln.
    final area = filledIndices.length;
    final density = math.max(18, (math.min(width, height) / 28).round());
    final sparkleCount = math.min(
      520,
      math.max(48, area ~/ density),
    );

    // Typische Sparkle-Größe: ~0.4–0.9 % der kürzeren Bildseite.
    final shortSide = math.min(width, height);
    final maxRadius = math.max(2, (shortSide * 0.007).round());

    void putPixel(int x, int y, int r, int g, int b) {
      if (x < 0 || y < 0 || x >= width || y >= height) return;
      final idx = y * width + x;
      if (!filledSet.contains(idx)) return;
      if (isLinePixel(original, x, y)) return;
      working.setPixelRgba(x, y, r, g, b, 255);
    }

    for (var i = 0; i < sparkleCount; i++) {
      final idx = filledIndices[random.nextInt(filledIndices.length)];
      final cx = idx % width;
      final cy = idx ~/ width;
      if (isLinePixel(original, cx, cy)) continue;

      final kind = random.nextDouble();
      final radius = math.max(1, 1 + random.nextInt(maxRadius));

      // Weiß / Pastell der Basisfarbe / warmes Gold.
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

      // Kreuz-Stern.
      for (var d = -radius; d <= radius; d++) {
        putPixel(cx + d, cy, r, g, b);
        putPixel(cx, cy + d, r, g, b);
      }

      // Diagonale Arme für größeren Sparkle.
      if (radius >= 2 && random.nextDouble() > 0.4) {
        final diag = math.max(1, radius - 1);
        for (var d = -diag; d <= diag; d++) {
          putPixel(cx + d, cy + d, r, g, b);
          putPixel(cx + d, cy - d, r, g, b);
        }
      }

      // Heller Kern.
      putPixel(cx, cy, 255, 255, 255);
      if (radius >= 2) {
        putPixel(cx - 1, cy, 255, 255, 255);
        putPixel(cx + 1, cy, 255, 255, 255);
        putPixel(cx, cy - 1, 255, 255, 255);
        putPixel(cx, cy + 1, 255, 255, 255);
      }
    }

    // Zusätzliche feine Glitzerpunkte für „Schimmer“.
    final dustCount = math.min(280, math.max(30, area ~/ (density * 2)));
    for (var i = 0; i < dustCount; i++) {
      final idx = filledIndices[random.nextInt(filledIndices.length)];
      final x = idx % width;
      final y = idx ~/ width;
      if (isLinePixel(original, x, y)) continue;
      final soft = random.nextDouble() > 0.5;
      if (soft) {
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
