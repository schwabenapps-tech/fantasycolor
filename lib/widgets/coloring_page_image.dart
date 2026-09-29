import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/coloring_page.dart';
import '../providers/coloring_progress_store.dart';
import '../utils/image_source.dart';

/// FileImage mit Versions-Key — sonst bleibt nach Speichern das alte Thumbnail.
class _VersionedFileImage extends FileImage {
  const _VersionedFileImage(super.file, {required this.version});

  final int version;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _VersionedFileImage &&
        other.file.path == file.path &&
        other.scale == scale &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(file.path, scale, version);
}

/// Ausmalbild auf weißem Papier – zeigt gespeicherten Fortschritt, falls vorhanden.
class ColoringPageImage extends StatelessWidget {
  const ColoringPageImage({
    super.key,
    required this.page,
    this.fit = BoxFit.contain,
    this.alignment = const Alignment(0, -0.12),
    this.borderRadius,
    this.placeholderColor = const Color(0xFF8FA0C8),
    this.placeholderSize = 28,
  });

  final ColoringPage page;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final Color placeholderColor;
  final double placeholderSize;

  @override
  Widget build(BuildContext context) {
    // Nullable-Lookup: kein Crash, wenn der Provider nach Hot-Reload noch fehlt.
    final progress = context.watch<ColoringProgressStore?>();
    final file = progress?.fileFor(page.id);
    final version = progress?.versionOf(page.id) ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        // Nur cacheWidth (Höhe folgt Aspect) — gleicher Key wie Precache.
        final logical = [
          if (maxW.isFinite && maxW > 0) maxW,
          if (maxH.isFinite && maxH > 0) maxH,
        ];
        final cacheW = logical.isEmpty
            ? null
            : (logical.reduce((a, b) => a > b ? a : b) * dpr)
                .round()
                .clamp(64, 2048);

        Widget image = ColoredBox(
          color: Colors.white,
          child: file != null
              ? Image(
                  image: ResizeImage.resizeIfNeeded(
                    cacheW,
                    null,
                    _VersionedFileImage(file, version: version),
                  ),
                  key: ValueKey('progress_${page.id}_$version'),
                  fit: fit,
                  alignment: alignment,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _sourceImage(cacheW),
                )
              : _sourceImage(cacheW),
        );

        if (borderRadius != null) {
          image = ClipRRect(borderRadius: borderRadius!, child: image);
        }

        return image;
      },
    );
  }

  Widget _sourceImage(int? cacheWidth) {
    final provider = imageProviderFor(page.assetPath);
    return Image(
      image: ResizeImage.resizeIfNeeded(cacheWidth, null, provider),
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Center(
        child: Icon(Icons.broken_image_outlined, color: placeholderColor),
      ),
    );
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
