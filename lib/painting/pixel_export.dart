import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/pixel_puzzle.dart';

/// Rendert den aktuellen Dot-Art-Stand als PNG (Vorschau oder fertiges Bild).
class PixelExporter {
  PixelExporter._();

  static const _paperArgb = 0xFFF7F4EE;
  static const playDotScale = 0.48;
  /// Fertiges Bild etwas dichter — wirkt geschlossener.
  static const denseDotScale = 0.54;

  /// Hochauflösendes fertiges / Zwischen-Bild (ganzes Raster als Dots).
  static Future<Uint8List> renderPng({
    required PixelPuzzle puzzle,
    required List<bool> filled,
    int cellSize = 16,
    bool emptyAsLightGray = true,
    bool dense = false,
  }) {
    return compute(
      _renderPngIsolate,
      _RenderPngArgs(
        cols: puzzle.cols,
        rows: puzzle.rows,
        cells: List<int>.from(puzzle.cells),
        paletteArgb: [
          for (final p in puzzle.palette) p.color.toARGB32(),
        ],
        filled: List<bool>.from(filled),
        cellSize: cellSize,
        emptyAsLightGray: emptyAsLightGray,
        dense: dense,
      ),
    );
  }

  /// Schnelle UI-Vorschau über Flutter Canvas (für Badge-Thumbnails).
  static Future<Uint8List> renderPreviewWithCanvas({
    required PixelPuzzle puzzle,
    required List<bool> filled,
    int maxSide = 256,
    bool dense = false,
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
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(_paperArgb),
    );

    final cellW = w / puzzle.cols;
    final cellH = h / puzzle.rows;
    final scale = dense ? denseDotScale : playDotScale;
    final radius = math.min(cellW, cellH) * scale;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var y = 0; y < puzzle.rows; y++) {
      for (var x = 0; x < puzzle.cols; x++) {
        final i = y * puzzle.cols + x;
        final color = puzzle.palette[puzzle.cells[i]].color;
        paint.color = filled[i]
            ? color
            : Color.lerp(const Color(_paperArgb), color, 0.16)!;
        canvas.drawCircle(
          Offset((x + 0.5) * cellW, (y + 0.5) * cellH),
          radius,
          paint,
        );
      }
    }

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(w.round().clamp(1, 2048), h.round().clamp(1, 2048));
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) {
      throw StateError('Dot-Art-Vorschau konnte nicht gerendert werden');
    }
    return bytes.buffer.asUint8List();
  }
}

class _RenderPngArgs {
  const _RenderPngArgs({
    required this.cols,
    required this.rows,
    required this.cells,
    required this.paletteArgb,
    required this.filled,
    required this.cellSize,
    required this.emptyAsLightGray,
    required this.dense,
  });

  final int cols;
  final int rows;
  final List<int> cells;
  final List<int> paletteArgb;
  final List<bool> filled;
  final int cellSize;
  final bool emptyAsLightGray;
  final bool dense;
}

Uint8List _renderPngIsolate(_RenderPngArgs args) {
  final width = args.cols * args.cellSize;
  final height = args.rows * args.cellSize;
  final image = img.Image(width: width, height: height, numChannels: 4);
  final scale =
      args.dense ? PixelExporter.denseDotScale : PixelExporter.playDotScale;
  const paper = PixelExporter._paperArgb;

  img.fill(
    image,
    color: img.ColorRgba8(
      (paper >> 16) & 0xFF,
      (paper >> 8) & 0xFF,
      paper & 0xFF,
      255,
    ),
  );

  final radius = math.max(1, (args.cellSize * scale).round());
  final paperR = (paper >> 16) & 0xFF;
  final paperG = (paper >> 8) & 0xFF;
  final paperB = paper & 0xFF;

  for (var y = 0; y < args.rows; y++) {
    for (var x = 0; x < args.cols; x++) {
      final i = y * args.cols + x;
      final argb = args.paletteArgb[args.cells[i]];
      final cr = (argb >> 16) & 0xFF;
      final cg = (argb >> 8) & 0xFF;
      final cb = argb & 0xFF;
      late final int r;
      late final int g;
      late final int b;
      if (args.filled[i]) {
        r = cr;
        g = cg;
        b = cb;
      } else if (args.emptyAsLightGray) {
        // Color.lerp(paper, color, 0.22)
        r = (paperR + ((cr - paperR) * 0.22)).round();
        g = (paperG + ((cg - paperG) * 0.22)).round();
        b = (paperB + ((cb - paperB) * 0.22)).round();
      } else {
        r = cr;
        g = cg;
        b = cb;
      }
      img.fillCircle(
        image,
        x: (x * args.cellSize + args.cellSize / 2).round(),
        y: (y * args.cellSize + args.cellSize / 2).round(),
        radius: radius,
        color: img.ColorRgba8(r, g, b, 255),
      );
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}
