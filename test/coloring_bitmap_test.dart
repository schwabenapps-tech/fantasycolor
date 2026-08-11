import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fantasy_color/painting/coloring_bitmap.dart';
import 'package:fantasy_color/data/paint_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads png and flood-fills a light region', () async {
    final bitmap = await ColoringBitmap.load('assets/coloring_pages/ballerina_1.png');
    expect(bitmap.width, greaterThan(100));
    expect(bitmap.height, greaterThan(100));

    // Center-ish background / dress area should be fillable on line art.
    final changed = bitmap.floodFill(
      bitmap.width ~/ 2,
      bitmap.height ~/ 3,
      color: const Color(0xFFFF4D6D),
      category: PaintCategory.solid,
    );
    expect(changed, greaterThan(0));
  });
}
