import 'dart:math';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';

final _svgSizePattern = RegExp(
  r'width="([\d.]+)(?:px)?"[^>]*height="([\d.]+)(?:px)?"',
  caseSensitive: false,
);

final _svgSizePatternAlt = RegExp(
  r'height="([\d.]+)(?:px)?"[^>]*width="([\d.]+)(?:px)?"',
  caseSensitive: false,
);

final _viewBoxPattern = RegExp(
  r'viewBox="\s*([-\d.]+)\s+([-\d.]+)\s+([\d.]+)\s+([\d.]+)\s*"',
  caseSensitive: false,
);

/// Liest Breite/Höhe aus dem SVG-Kopf (width/height oder viewBox).
({double width, double height}) parseSvgSize(String svgHead) {
  final sized = _svgSizePattern.firstMatch(svgHead);
  if (sized != null) {
    return (
      width: double.parse(sized.group(1)!),
      height: double.parse(sized.group(2)!),
    );
  }

  final sizedAlt = _svgSizePatternAlt.firstMatch(svgHead);
  if (sizedAlt != null) {
    return (
      width: double.parse(sizedAlt.group(2)!),
      height: double.parse(sizedAlt.group(1)!),
    );
  }

  final viewBox = _viewBoxPattern.firstMatch(svgHead);
  if (viewBox != null) {
    return (
      width: double.parse(viewBox.group(3)!),
      height: double.parse(viewBox.group(4)!),
    );
  }

  return (width: 1, height: 1);
}

/// Lädt alle SVG-Ausmalbilder aus `assets/coloring_pages/`.
/// Nach dem Umbenennen oder Hinzufügen von Dateien reicht ein App-Neustart.
Future<List<ColoringPage>> loadColoringPages({
  bool shuffle = true,
  Random? random,
}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where(
        (path) =>
            path.startsWith('assets/coloring_pages/') &&
            path.toLowerCase().endsWith('.svg'),
      )
      .toList()
    ..sort();

  final pages = <ColoringPage>[];
  for (final path in paths) {
    final raw = await rootBundle.loadString(path);
    final head = raw.length > 1200 ? raw.substring(0, 1200) : raw;
    final size = parseSvgSize(head);
    pages.add(
      ColoringPage.fromAssetPath(
        path,
        width: size.width,
        height: size.height,
      ),
    );
  }

  if (shuffle) {
    pages.shuffle(random ?? Random());
  }
  return List<ColoringPage>.unmodifiable(pages);
}
