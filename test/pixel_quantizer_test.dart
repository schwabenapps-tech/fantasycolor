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
    // Zwei fast gleiche Rottöne + ein klares Blau → Rot darf nicht doppelt sein.
    final image = img.Image(width: 64, height: 32, numChannels: 4);
    for (var y = 0; y < 32; y++) {
      for (var x = 0; x < 64; x++) {
        if (x < 20) {
          image.setPixelRgba(x, y, 220, 40, 40, 255);
        } else if (x < 40) {
          image.setPixelRgba(x, y, 235, 55, 48, 255);
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
}
