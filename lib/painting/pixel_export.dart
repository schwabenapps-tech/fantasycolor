import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/pixel_puzzle.dart';

/// Rendert den aktuellen Pixel-Stand als PNG (Vorschau oder fertiges Bild).
class PixelExporter {
  PixelExporter._();

  /// Hochauflösendes fertiges / Zwischen-Bild (ganzes Raster).
  static Future<Uint8List> renderPng({
    required PixelPuzzle puzzle,
    required List<bool> filled,
    int cellSize = 16,
    bool emptyAsLightGray = true,
  }) async {
    final width = puzzle.cols * cellSize;
    final height = puzzle.rows * cellSize;
    final image = img.Image(width: width, height: height, numChannels: 4);

    for (var y = 0; y < puzzle.rows; y++) {
      for (var x = 0; x < puzzle.cols; x++) {
        final i = y * puzzle.cols + x;
        final color = puzzle.palette[puzzle.cells[i]].color;
        final fill = filled[i]
            ? color
            : (emptyAsLightGray
                ? Color.lerp(Colors.white, color, 0.18)!
                : color);
        final argb = fill.toARGB32();
        final r = (argb >> 16) & 0xFF;
        final g = (argb >> 8) & 0xFF;
        final b = argb & 0xFF;
        img.fillRect(
          image,
          x1: x * cellSize,
          y1: y * cellSize,
          x2: (x + 1) * cellSize,
          y2: (y + 1) * cellSize,
          color: img.ColorRgba8(r, g, b, 255),
        );
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  /// Schnelle UI-Vorschau über Flutter Canvas (für Badge-Thumbnails).
  static Future<Uint8List> renderPreviewWithCanvas({
    required PixelPuzzle puzzle,
    required List<bool> filled,
    int maxSide = 256,
  }) async {
    final aspect = puzzle.cols / puzzle.rows;
    final double w;
    final double h;
    if (aspect >= 1) {
      w = maxSide.toDouble();
      h = maxSide / aspect;
    } else {
      h = maxSide.toDouble();
      w = maxSide * aspect;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final cellW = w / puzzle.cols;
    final cellH = h / puzzle.rows;

    for (var y = 0; y < puzzle.rows; y++) {
      for (var x = 0; x < puzzle.cols; x++) {
        final i = y * puzzle.cols + x;
        final color = puzzle.palette[puzzle.cells[i]].color;
        final paint = Paint()
          ..color = filled[i]
              ? color
              : Color.lerp(const Color(0xFFF4F6FA), color, 0.16)!;
        canvas.drawRect(
          Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.round().clamp(1, 2048), h.round().clamp(1, 2048));
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) {
      throw StateError('Pixel-Vorschau konnte nicht gerendert werden');
    }
    return bytes.buffer.asUint8List();
  }
}
