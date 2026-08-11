import 'package:flutter/material.dart';

import '../models/coloring_page.dart';

/// Ausmalbild auf weißem Papier im exakten Seitenverhältnis.
class ColoringPageImage extends StatelessWidget {
  const ColoringPageImage({
    super.key,
    required this.page,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.placeholderColor = const Color(0xFF8FA0C8),
    this.placeholderSize = 28,
  });

  final ColoringPage page;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color placeholderColor;
  final double placeholderSize;

  @override
  Widget build(BuildContext context) {
    Widget image = ColoredBox(
      color: Colors.white,
      child: Image.asset(
        page.assetPath,
        fit: fit,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Center(
          child: Icon(Icons.broken_image_outlined, color: placeholderColor),
        ),
      ),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

/// Weißes Blatt in echter Bildproportion, eingepasst in den verfügbaren Platz.
class ColoringPageSheet extends StatelessWidget {
  const ColoringPageSheet({
    super.key,
    required this.page,
    this.borderRadius,
    this.placeholderColor = const Color(0xFF8FA0C8),
    this.placeholderSize = 32,
  });

  final ColoringPage page;
  final BorderRadius? borderRadius;
  final Color placeholderColor;
  final double placeholderSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final ratio = page.aspectRatio;

        var width = maxW;
        var height = width / ratio;
        if (height > maxH) {
          height = maxH;
          width = height * ratio;
        }

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: ColoringPageImage(
              page: page,
              fit: BoxFit.contain,
              borderRadius: borderRadius,
              placeholderColor: placeholderColor,
              placeholderSize: placeholderSize,
            ),
          ),
        );
      },
    );
  }
}
