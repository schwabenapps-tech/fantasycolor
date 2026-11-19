import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sticker_catalog.dart';
import '../providers/coloring_sticker_placements_store.dart';
import '../providers/sticker_collection_store.dart';
import '../services/analytics_service.dart';
import '../utils/image_source.dart';

/// Overlay: besessene Stickers auf dem Ausmalbild platzieren.
class ColoringStickerLayer extends StatefulWidget {
  const ColoringStickerLayer({
    super.key,
    required this.pageId,
    required this.child,
    this.editable = true,
  });

  final String pageId;
  final Widget child;
  final bool editable;

  @override
  State<ColoringStickerLayer> createState() => _ColoringStickerLayerState();
}

class _ColoringStickerLayerState extends State<ColoringStickerLayer> {
  bool _pickerOpen = false;

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
            if (widget.editable)
              Positioned(
                right: 8,
                bottom: 8,
                child: FloatingActionButton.small(
                  heroTag: 'sticker_place_${widget.pageId}',
                  backgroundColor: const Color(0xFF2E4A72),
                  onPressed: () => setState(() => _pickerOpen = true),
                  child: const Icon(Icons.sticky_note_2_outlined),
                ),
              ),
            if (_pickerOpen)
              _StickerPickerSheet(
                onClose: () => setState(() => _pickerOpen = false),
                onPick: (id) async {
                  await context.read<ColoringStickerPlacementsStore>().add(
                        widget.pageId,
                        PlacedSticker(stickerId: id, x: 0.5, y: 0.5),
                      );
                  AnalyticsService.instance.logStickerPlaced(widget.pageId);
                  if (mounted) setState(() => _pickerOpen = false);
                },
              ),
          ],
        );
      },
    );
  }
}

class _PlacedStickerView extends StatelessWidget {
  const _PlacedStickerView({
    required this.placement,
    required this.entry,
    required this.width,
    required this.height,
    required this.editable,
    required this.onMove,
    required this.onScale,
    required this.onRemove,
  });

  final PlacedSticker placement;
  final StickerEntry? entry;
  final double width;
  final double height;
  final bool editable;
  final void Function(double x, double y) onMove;
  final void Function(double scale) onScale;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final size = (width * placement.scale).clamp(28.0, width * 0.5);
    final left = placement.x * width - size / 2;
    final top = placement.y * height - size / 2;
    final img = entry != null && isLocalImageAvailable(entry!.assetPath)
        ? Image(
            image: imageProviderFor(entry!.assetPath),
            fit: BoxFit.contain,
          )
        : const Icon(Icons.sticky_note_2, color: Colors.white70);

    Widget child = SizedBox(width: size, height: size, child: img);

    if (!editable) {
      return Positioned(left: left, top: top, child: child);
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (d) {
          final nx = ((placement.x * width + d.delta.dx) / width).clamp(0.05, 0.95);
          final ny = ((placement.y * height + d.delta.dy) / height).clamp(0.05, 0.95);
          onMove(nx, ny);
        },
        onLongPress: onRemove,
        onScaleUpdate: (d) {
          if (d.pointerCount >= 2) onScale(placement.scale * d.scale);
        },
        child: child,
      ),
    );
  }
}

class _StickerPickerSheet extends StatelessWidget {
  const _StickerPickerSheet({
    required this.onClose,
    required this.onPick,
  });

  final VoidCallback onClose;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StickerCollectionStore>();
    final owned = [
      for (final s in store.catalog?.stickers ?? const <StickerEntry>[])
        if (store.owns(s.id)) s,
    ];

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 220,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2A44),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Stickers',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                Expanded(
                  child: owned.isEmpty
                      ? const Center(
                          child: Text(
                            'No stickers yet',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: owned.length,
                          itemBuilder: (context, i) {
                            final s = owned[i];
                            return GestureDetector(
                              onTap: () => onPick(s.id),
                              child: isLocalImageAvailable(s.assetPath)
                                  ? Image(
                                      image: imageProviderFor(s.assetPath),
                                      fit: BoxFit.contain,
                                    )
                                  : const Icon(
                                      Icons.sticky_note_2,
                                      color: Colors.white54,
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
