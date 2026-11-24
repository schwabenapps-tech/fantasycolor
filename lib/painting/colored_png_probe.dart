import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Erkennt, ob ein Ausmal-PNG echte Füllfarbe hat (nicht nur Linie/Weiß).
class ColoredPngProbe {
  ColoredPngProbe._();

  /// Grober Check für gespeicherte Progress-PNGs (im Hintergrund-Isolate).
  static Future<bool> hasFillColors(Uint8List pngBytes) {
    return compute(_hasFillColorsIsolate, pngBytes);
  }

  static bool _hasFillColorsIsolate(Uint8List pngBytes) {
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null || decoded.width < 2 || decoded.height < 2) {
      return false;
    }

    final stepX = math.max(1, decoded.width ~/ 96);
    final stepY = math.max(1, decoded.height ~/ 96);
    var samples = 0;
    var fills = 0;

    for (var y = 0; y < decoded.height; y += stepY) {
      for (var x = 0; x < decoded.width; x += stepX) {
        final p = decoded.getPixel(x, y);
        samples++;
        if (_looksLikeFill(
          p.r.toInt(),
          p.g.toInt(),
          p.b.toInt(),
          p.a.toInt(),
        )) {
          fills++;
        }
      }
    }

    if (samples == 0) return false;
    return fills >= 12 || fills / samples >= 0.008;
  }

  static bool _looksLikeFill(int r, int g, int b, int a) {
    if (a < 40) return false;
    final maxc = math.max(r, math.max(g, b));
    final minc = math.min(r, math.min(g, b));
    final lum = (r + g + b) / 3.0;
    final sat = maxc - minc;

    if (lum < 48) return false;
    if (lum > 242 && sat < 20) return false;
    if (lum > 228 && sat < 12) return false;

    if (sat >= 22) return true;
    if (lum > 55 && lum < 215) return true;
    return false;
  }
}
