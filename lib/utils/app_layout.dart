import 'package:flutter/material.dart';

/// Gemeinsame Breakpoints für Phone / Tablet (Landscape primär).
class AppLayout {
  AppLayout._(this.size);

  factory AppLayout.of(BuildContext context) {
    return AppLayout._(MediaQuery.sizeOf(context));
  }

  final Size size;

  /// Typische Tablet-Grenze (iPad mini / große Android-Tablets).
  bool get isTablet => size.shortestSide >= 600;

  bool get isLargeTablet => size.shortestSide >= 900;

  double get galleryTileHeight {
    final raw = size.height * (isTablet ? 0.48 : 0.56);
    final maxH = isLargeTablet
        ? 420.0
        : isTablet
            ? 360.0
            : size.height * 0.62;
    return raw.clamp(180.0, maxH);
  }

  double get galleryTileWidth => galleryTileHeight * 0.78;

  double get galleryTopSpacer => size.height * (isTablet ? 0.08 : 0.14);

  double get hubHorizontalPadding =>
      size.width * (isTablet ? 0.1 : 0.08);

  double get hubVerticalPadding =>
      size.height * (isTablet ? 0.12 : 0.1);

  double get hubIconSize => isLargeTablet
      ? 88.0
      : isTablet
          ? 76.0
          : 64.0;

  double get hubMaxCardWidth => isTablet ? 280.0 : double.infinity;

  double get paintRailWidth => isTablet ? 188.0 : 148.0;

  double get puzzleTrayHeight => isTablet ? 132.0 : 108.0;

  double get puzzleSideTrayWidth => isTablet ? 148.0 : 118.0;

  int favoritesCrossAxisCount({required bool landscape}) {
    if (isLargeTablet) return landscape ? 5 : 4;
    if (isTablet) return landscape ? 4 : 3;
    return size.width > 900 ? 4 : 3;
  }
}
