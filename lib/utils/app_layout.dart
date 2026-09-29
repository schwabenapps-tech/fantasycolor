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

  bool get isLandscape => size.width > size.height;

  bool get isPortrait => !isLandscape;

  /// Gemeinsame Vorschaugröße Ausmalen/Puzzle — Landscape füllt den Screen.
  double get galleryTileHeight {
    if (isLandscape) {
      final raw = size.height * (isTablet ? 0.62 : 0.68);
      final maxH = isLargeTablet
          ? 520.0
          : isTablet
              ? 440.0
              : size.height * 0.76;
      return raw.clamp(220.0, maxH);
    }
    final raw = size.height * (isTablet ? 0.48 : 0.56);
    final maxH = isLargeTablet
        ? 420.0
        : isTablet
            ? 360.0
            : size.height * 0.62;
    return raw.clamp(180.0, maxH);
  }

  /// Alias — gleiche Größe wie [galleryTileHeight].
  double get puzzleGalleryTileHeight => galleryTileHeight;

  /// Weniger Top-Abstand in Landscape, damit die Vorschau den Screen füllt.
  double get galleryTopSpacer =>
      isLandscape ? size.height * (isTablet ? 0.05 : 0.08) : size.height * (isTablet ? 0.08 : 0.14);

  double get puzzleGalleryTopSpacer => galleryTopSpacer;

  double get galleryTileWidth => galleryTileHeight * 0.78;

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

  /// Untere Farbleiste beim Ausmalen (Fill-only).
  double get paintBarHeight => isTablet ? 96.0 : 84.0;

  double get puzzleTrayHeight => isTablet ? 132.0 : 108.0;

  double get puzzleSideTrayWidth => isTablet ? 148.0 : 118.0;

  int favoritesCrossAxisCount({required bool landscape}) {
    if (isLargeTablet) return landscape ? 5 : 4;
    if (isTablet) return landscape ? 4 : 3;
    return size.width > 900 ? 4 : 3;
  }

  /// Portrait-Auswahlgitter (Ausmalen / Puzzle).
  int get galleryGridCrossAxisCount {
    if (isLargeTablet) return 4;
    if (isTablet) return 3;
    return 2;
  }

  /// Einheitliches Kachel-Format (Portrait-Vorschaugitter).
  double get galleryGridChildAspectRatio => 0.82;

  EdgeInsets galleryGridPadding(Size size) => EdgeInsets.fromLTRB(
        size.width * 0.045,
        size.height * 0.02,
        size.width * 0.045,
        size.height * 0.03,
      );
}
