import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../data/paint_catalog.dart';
import 'flood_fill_tuning.dart';
import 'flood_fill_worker.dart';

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

  /// Anti-Alias- / Rand-Stärke (skalierbar: standard / soft / tight).
  static FloodFillTuning tuning = FloodFillTuning.standard;

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

  Uint8List originalSnapshot() =>
      Uint8List.fromList(original.getBytes(order: img.ChannelOrder.rgba));

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
  ///
  /// Bei anderer Größe (ausgetauschtes Motiv) → false, kein Aufblasen alter Bilder.
  bool applyWorkingPng(Uint8List pngBytes) {
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) return false;
    final rgba = decoded.convert(numChannels: 4);
    if (rgba.width != width || rgba.height != height) {
      return false;
    }
    working = rgba;
    return true;
  }

  /// Aktuelles Arbeitsbild als PNG-Bytes.
  Uint8List encodeWorkingPng() =>
      Uint8List.fromList(img.encodePng(working));

  bool isLinePixel(img.Image source, int x, int y) {
    final p = source.getPixel(x, y);
    final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    return lum <= tuning.hardLineLuminanceMax;
  }

  /// Füllt die zusammenhängende helle Region um (x,y) im Hintergrund-Isolate.
  Future<int> floodFillAsync(
    int x,
    int y, {
    required ui.Color color,
    required PaintCategory category,
    bool erase = false,
  }) async {
    final result = await runFloodFill(
      FloodFillRequest(
        workingBytes: snapshot(),
        originalBytes: originalSnapshot(),
        width: width,
        height: height,
        x: x,
        y: y,
        colorArgb: color.toARGB32(),
        categoryIndex: category.index,
        erase: erase,
        tuning: tuning,
      ),
    );
    if (result.changed <= 0) return 0;
    restoreSnapshot(result.workingBytes);
    return result.changed;
  }

  /// Füllt die zusammenhängende helle Region um (x,y) — synchron (Tests).
  int floodFill(
    int x,
    int y, {
    required ui.Color color,
    required PaintCategory category,
    bool erase = false,
  }) {
    final t = tuning;
    if (x < 0 || y < 0 || x >= width || y >= height) return 0;
    final seed = original.getPixel(x, y);
    final seedLum = 0.299 * seed.r + 0.587 * seed.g + 0.114 * seed.b;
    if (seedLum < t.fillRegionLuminanceMin) return 0;

    final targetR = color.r * 255.0;
    final targetG = color.g * 255.0;
    final targetB = color.b * 255.0;

    final painted = Uint8List(width * height);
    final stackX = <int>[x];
    final stackY = <int>[y];
    var count = 0;

    void paintAt(int cx, int cy) {
      final orig = original.getPixel(cx, cy);
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
    }

    while (stackX.isNotEmpty) {
      final cx = stackX.removeLast();
      final cy = stackY.removeLast();
      if (cx < 0 || cy < 0 || cx >= width || cy >= height) continue;
      final idx = cy * width + cx;
      if (painted[idx] == 1) continue;

      final orig = original.getPixel(cx, cy);
      final origLum = 0.299 * orig.r + 0.587 * orig.g + 0.114 * orig.b;
      if (origLum < t.fillRegionLuminanceMin) continue;

      painted[idx] = 1;
      paintAt(cx, cy);
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

    final neighborDeltas = t.fringeDiagonals
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

    for (var pass = 0; pass < t.fringeExpandPasses; pass++) {
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
          final p = original.getPixel(nx, ny);
          final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
          if (lum <= t.hardLineLuminanceMax) continue;
          if (lum < t.fringeLuminanceMin) continue;
          painted[nIdx] = 1;
          paintAt(nx, ny);
          count++;
          grew++;
        }
      }
      if (grew == 0) break;
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
      case PaintCategory.solid:
        break;
    }

    return (
      r.round().clamp(0, 255),
      g.round().clamp(0, 255),
      b.round().clamp(0, 255),
    );
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
