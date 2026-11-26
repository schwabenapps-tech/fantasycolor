import 'dart:typed_data';

import 'package:fantasy_color/models/pixel_puzzle.dart';
import 'package:fantasy_color/painting/pixel_quantizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quantizes puzzle asset into numbered palette grid', () async {
    final puzzle = await PixelQuantizer.fromAsset(
      'assets/puzzle_images/img_1875.jpg',
      difficulty: PixelDifficulty.standard,
    );

    expect(puzzle.cols, greaterThanOrEqualTo(8));
    expect(puzzle.rows, greaterThanOrEqualTo(8));
    expect(puzzle.cells.length, puzzle.cols * puzzle.rows);
    expect(puzzle.palette, isNotEmpty);
    expect(puzzle.palette.first.number, 1);
    expect(puzzle.cells.every((c) => c >= 0 && c < puzzle.palette.length), isTrue);
  });

  test('merges near-duplicate flat colors into one palette entry', () async {
    // Zwei praktisch gleiche Rottöne + ein klares Blau → Rot nicht doppelt.
    final image = img.Image(width: 64, height: 32, numChannels: 4);
    for (var y = 0; y < 32; y++) {
      for (var x = 0; x < 64; x++) {
        if (x < 20) {
          image.setPixelRgba(x, y, 220, 40, 40, 255);
        } else if (x < 40) {
          image.setPixelRgba(x, y, 224, 44, 42, 255);
        } else {
          image.setPixelRgba(x, y, 40, 90, 220, 255);
        }
      }
    }
    final bytes = Uint8List.fromList(img.encodePng(image));
    final puzzle = await PixelQuantizer.fromBytes(
      bytes,
      difficulty: PixelDifficulty.standard,
    );

    expect(puzzle.palette.length, 2);
  });

  test('keeps distinct purple hues as separate palette colors', () async {
    final image = img.Image(width: 90, height: 30, numChannels: 4);
    for (var y = 0; y < 30; y++) {
      for (var x = 0; x < 90; x++) {
        if (x < 30) {
          image.setPixelRgba(x, y, 180, 120, 220, 255); // lavendel
        } else if (x < 60) {
          image.setPixelRgba(x, y, 110, 40, 170, 255); // tiefviolett
        } else {
          image.setPixelRgba(x, y, 60, 200, 120, 255); // grün
        }
      }
    }
    final bytes = Uint8List.fromList(img.encodePng(image));
    final puzzle = await PixelQuantizer.fromBytes(
      bytes,
      difficulty: PixelDifficulty.standard,
    );

    expect(puzzle.palette.length, greaterThanOrEqualTo(3));
  });

  test('preserves black outline as its own palette color', () async {
    final image = img.Image(width: 96, height: 96, numChannels: 4);
    for (var y = 0; y < 96; y++) {
      for (var x = 0; x < 96; x++) {
        final onLine = x < 4 || y < 4 || x >= 92 || y >= 92 ||
            (x > 44 && x < 52) ||
            (y > 44 && y < 52);
        if (onLine) {
          image.setPixelRgba(x, y, 20, 20, 20, 255);
        } else if (x < 48) {
          image.setPixelRgba(x, y, 240, 60, 60, 255);
        } else {
          image.setPixelRgba(x, y, 60, 140, 240, 255);
        }
      }
    }
    final bytes = Uint8List.fromList(img.encodePng(image));
    final puzzle = await PixelQuantizer.fromBytes(
      bytes,
      difficulty: PixelDifficulty.standard,
    );

    final hasLine = puzzle.palette.any((p) {
      final c = p.color;
      final lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
      return lum < 60;
    });
    expect(hasLine, isTrue);
    expect(puzzle.palette.length, greaterThanOrEqualTo(3));
  });
}
