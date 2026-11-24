import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// PNG encode/decode abseits vom UI-Isolate (ANR-Schutz).
class DecodedRgba {
  const DecodedRgba({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;

  /// Frische RGBA-Kopie (offset 0) — sicher für Isolate + Image.fromBytes.
  final Uint8List rgba;
}

Future<DecodedRgba?> decodePngToRgba(Uint8List pngBytes) {
  return compute(_decodePngToRgba, pngBytes);
}

Future<Uint8List> encodeRgbaToPng({
  required Uint8List rgba,
  required int width,
  required int height,
}) {
  // Kopie mit offset 0 — Views mit offsetInBytes ≠ 0 knacken sonst encodePng.
  final copy = Uint8List.fromList(rgba);
  return compute(
    _encodeRgbaToPng,
    _EncodeRgbaArgs(rgba: copy, width: width, height: height),
  );
}

DecodedRgba? _decodePngToRgba(Uint8List pngBytes) {
  final decoded = img.decodeImage(pngBytes);
  if (decoded == null) return null;
  final rgba = decoded.convert(numChannels: 4);
  return DecodedRgba(
    width: rgba.width,
    height: rgba.height,
    rgba: Uint8List.fromList(rgba.getBytes(order: img.ChannelOrder.rgba)),
  );
}

class _EncodeRgbaArgs {
  const _EncodeRgbaArgs({
    required this.rgba,
    required this.width,
    required this.height,
  });

  final Uint8List rgba;
  final int width;
  final int height;
}

Uint8List _encodeRgbaToPng(_EncodeRgbaArgs args) {
  final expected = args.width * args.height * 4;
  if (args.rgba.length < expected) {
    throw StateError(
      'RGBA buffer too small: ${args.rgba.length} < $expected',
    );
  }
  final image = img.Image.fromBytes(
    width: args.width,
    height: args.height,
    bytes: args.rgba.buffer,
    bytesOffset: args.rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodePng(image));
}
