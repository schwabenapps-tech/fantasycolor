import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sticker_catalog.dart';
import '../providers/coloring_sticker_placements_store.dart';
import '../providers/sticker_collection_store.dart';
import '../utils/image_source.dart';

/// Overlay: besessene Stickers auf dem Ausmalbild platzieren.
class ColoringStickerLayer extends StatefulWidget {
  const ColoringStickerLayer({
    super.key,
    required this.pageId,
    required this.child,
    this.editable = true,
    this.eraseMode = false,
  });

  final String pageId;
  final Widget child;
  final bool editable;
  /// Radierer aktiv — Tippen entfernt den Sticker.
  final bool eraseMode;

  @override
  State<ColoringStickerLayer> createState() => _ColoringStickerLayerState();
}

class _ColoringStickerLayerState extends State<ColoringStickerLayer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ColoringStickerPlacementsStore>().loadPage(widget.pageId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final placements = context.watch<ColoringStickerPlacementsStore>();
    final stickers = placements.forPage(widget.pageId);
    final catalog = context.watch<StickerCollectionStore>().catalog;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            for (var i = 0; i < stickers.length; i++)
              _PlacedStickerView(
                placement: stickers[i],
                entry: catalog?.byId(stickers[i].stickerId),
                width: w,
                height: h,
                editable: widget.editable,
                eraseMode: widget.eraseMode,
                onMove: (nx, ny) {
                  final updated = stickers[i].copyWith(x: nx, y: ny);
                  context
                      .read<ColoringStickerPlacementsStore>()
                      .updateAt(widget.pageId, i, updated);
                },
                onScale: (s) {
                  final updated = stickers[i].copyWith(
                    scale: s.clamp(0.08, 0.55),
                  );
                  context
                      .read<ColoringStickerPlacementsStore>()
                      .updateAt(widget.pageId, i, updated);
                },
                onRemove: () {
                  context
                      .read<ColoringStickerPlacementsStore>()
                      .removeAt(widget.pageId, i);
                },
              ),
          ],
        );
      },
    );
  }
}

class _PlacedStickerView extends StatefulWidget {
  const _PlacedStickerView({
    required this.placement,
    required this.entry,
    required this.width,
    required this.height,
    required this.editable,
    required this.eraseMode,
    required this.onMove,
    required this.onScale,
    required this.onRemove,
  });

  final PlacedSticker placement;
  final StickerEntry? entry;
  final double width;
  final double height;
  final bool editable;
  final bool eraseMode;
  final void Function(double x, double y) onMove;
  final void Function(double scale) onScale;
  final VoidCallback onRemove;

  @override
  State<_PlacedStickerView> createState() => _PlacedStickerViewState();
}

class _PlacedStickerViewState extends State<_PlacedStickerView> {
  double _baseX = 0;
  double _baseY = 0;
  double _baseScale = 1;

  @override
  Widget build(BuildContext context) {
    final placement = widget.placement;
    final width = widget.width;
    final height = widget.height;
    final size = (width * placement.scale).clamp(28.0, width * 0.5);
    final left = placement.x * width - size / 2;
    final top = placement.y * height - size / 2;
    final entry = widget.entry;
    final img = entry != null && isLocalImageAvailable(entry.assetPath)
        ? Image(
            image: imageProviderFor(entry.assetPath),
            fit: BoxFit.contain,
          )
        : const Icon(Icons.sticky_note_2, color: Colors.white70);

    Widget child = SizedBox(width: size, height: size, child: img);

    if (!widget.editable) {
      return Positioned(left: left, top: top, child: child);
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: widget.eraseMode ? widget.onRemove : null,
        onLongPress: widget.eraseMode ? null : widget.onRemove,
        onDoubleTap: widget.eraseMode
            ? null
            : () {
                // Doppeltipp: klein → mittel → groß → klein
                final s = placement.scale;
                final next = s < 0.16
                    ? 0.22
                    : s < 0.30
                        ? 0.40
                        : 0.12;
                widget.onScale(next);
              },
        onScaleStart: widget.eraseMode
            ? null
            : (_) {
                _baseX = placement.x;
                _baseY = placement.y;
                _baseScale = placement.scale;
              },
        onScaleUpdate: widget.eraseMode
            ? null
            : (d) {
                final nx = ((_baseX * width + d.focalPointDelta.dx) / width)
                    .clamp(0.05, 0.95);
                final ny = ((_baseY * height + d.focalPointDelta.dy) / height)
                    .clamp(0.05, 0.95);
                _baseX = nx;
                _baseY = ny;
                widget.onMove(nx, ny);
                // Zwei Finger (oder Trackpad): Größe anpassen.
                if ((d.pointerCount >= 2 || (d.scale - 1.0).abs() > 0.01)) {
                  widget.onScale(
                    (_baseScale * d.scale).clamp(0.08, 0.55),
                  );
                }
              },
        child: child,
      ),
    );
  }
}
