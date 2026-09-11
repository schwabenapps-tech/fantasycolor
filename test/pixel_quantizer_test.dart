import 'package:fantasy_color/models/pixel_puzzle.dart';
import 'package:fantasy_color/painting/pixel_quantizer.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
