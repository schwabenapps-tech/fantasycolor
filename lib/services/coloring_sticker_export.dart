import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../providers/coloring_sticker_placements_store.dart';
import '../utils/image_source.dart';

/// Brennt platzierte Stickers in ein Ausmal-PNG ein.
class ColoringStickerExport {
  ColoringStickerExport._();

  static Future<Uint8List> bake({
    required Uint8List basePng,
    required List<PlacedSticker> placements,
    required String? Function(String stickerId) assetPathFor,
  }) async {
    if (placements.isEmpty) return basePng;

    final baseCodec = await ui.instantiateImageCodec(basePng);
    final baseFrame = await baseCodec.getNextFrame();
    final base = baseFrame.image;
    final w = base.width;
    final h = base.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(base, Offset.zero, Paint());

    for (final p in placements) {
      final path = assetPathFor(p.stickerId);
      if (path == null || !isLocalImageAvailable(path)) continue;
      try {
        final bytes = await loadImageBytes(path);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final sticker = frame.image;
        final size = (w * p.scale).clamp(16.0, w * 0.6);
        final dx = p.x * w - size / 2;
        final dy = p.y * h - size / 2;
        final src = Rect.fromLTWH(
          0,
          0,
          sticker.width.toDouble(),
          sticker.height.toDouble(),
        );
        final dst = Rect.fromLTWH(dx, dy, size, size);
        canvas.save();
        canvas.translate(dx + size / 2, dy + size / 2);
        canvas.rotate(p.rotation);
        canvas.translate(-(dx + size / 2), -(dy + size / 2));
        canvas.drawImageRect(sticker, src, dst, Paint());
        canvas.restore();
        sticker.dispose();
      } catch (_) {}
    }

    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    base.dispose();
    out.dispose();
    return data!.buffer.asUint8List();
  }
}
