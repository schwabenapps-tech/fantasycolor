import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bauble_hub_portal.dart';

class HubArcItem {
  const HubArcItem({
    required this.id,
    required this.title,
    required this.frame,
    required this.onTap,
    this.coverAsset,
    this.coverAssets,
    this.subtitle,
    this.badge,
    this.slideOffset = Duration.zero,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? coverAsset;
  final List<String>? coverAssets;
  final BaubleFrameColor frame;
  final String? badge;
  final Duration slideOffset;
  final VoidCallback onTap;
}

/// Portrait: vertikale Liste.
/// Landscape: Bluey-artiger Halbkreis-Coverflow —
/// Bubbles stehen versetzt auf einem festen Bogen und gleiten
/// seitwärts (kein Rad, das um die eigene Achse dreht).
class HubArcCarousel extends StatefulWidget {
  const HubArcCarousel({
    super.key,
    required this.items,
  });

  final List<HubArcItem> items;

  @override
  State<HubArcCarousel> createState() => _HubArcCarouselState();
}

class _HubArcCarouselState extends State<HubArcCarousel> {
  final _scroll = ScrollController();
  double _itemExtent = 160;
  Offset? _down;
  bool _moved = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double get _offset {
    if (!_scroll.hasClients || _itemExtent <= 0) return 0;
    final max = math.max(widget.items.length - 1, 0).toDouble();
    return (_scroll.offset / _itemExtent).clamp(0.0, max);
  }

  void _openFocus() {
    if (widget.items.isEmpty) return;
    final i = _offset.round().clamp(0, widget.items.length - 1);
    widget.items[i].onTap();
  }

  Future<void> _snapToNearest() async {
    if (!_scroll.hasClients || widget.items.isEmpty) return;
    final target =
        _offset.round().clamp(0, widget.items.length - 1) * _itemExtent;
    if ((_scroll.offset - target).abs() < 1) return;
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        if (landscape) {
          return _buildLandscape(constraints, items);
        }
        return _buildPortrait(constraints, items);
      },
    );
  }

  Widget _buildPortrait(BoxConstraints constraints, List<HubArcItem> items) {
    final w = constraints.maxWidth;
    final itemSize = (w * 0.58).clamp(160.0, 240.0);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, i) {
        final item = items[i];
        return Center(
          child: SizedBox(
            width: itemSize,
            height: itemSize + 36,
            child: BaubleHubPortal(
              key: ValueKey('bauble_${item.id}'),
              title: item.title,
              subtitle: item.subtitle,
              coverAsset: item.coverAsset,
              coverAssets: item.coverAssets,
              frame: item.frame,
              badge: item.badge,
              slideOffset: item.slideOffset,
              onTap: item.onTap,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLandscape(BoxConstraints constraints, List<HubArcItem> items) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;

    const labelPad = 40.0;
    final maxItem = math.max(120.0, h - labelPad - 8);
    // Maximal groß — Landscape hat viel Platz.
    final itemSize = math
        .min(math.min(h * 0.88, w * 0.44), maxItem)
        .clamp(160.0, math.min(380.0, maxItem))
        .toDouble();
    final boxH = itemSize + labelPad;

    // Horizontaler Abstand zwischen Bubble-Zentren (Coverflow, nicht Orbit).
    final stepX = itemSize * 0.86;
    // Wie stark Seiten-Bubbles nach unten rutschen → Halbkreis-Versatz.
    final arcDrop = (h * 0.12).clamp(20.0, 56.0);
    // Fokus sitzt mittig.
    final focusY = h * 0.48;

    final extent = (w * 0.28).clamp(120.0, 180.0).toDouble();
    _itemExtent = extent;
    final sidePad = math.max(0.0, (w - extent) / 2);

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _scroll,
          builder: (context, _) {
            final offset = _offset;
            final order = List<int>.generate(items.length, (i) => i)
              ..sort((a, b) {
                final da = (a - offset).abs();
                final db = (b - offset).abs();
                return db.compareTo(da);
              });
            return IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final i in order)
                    _coverflowItem(
                      items[i],
                      i: i,
                      offset: offset,
                      focusY: focusY,
                      stepX: stepX,
                      arcDrop: arcDrop,
                      itemSize: itemSize,
                      boxH: boxH,
                      viewport: Size(w, h),
                    ),
                ],
              ),
            );
          },
        ),
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _down = e.position;
            _moved = false;
          },
          onPointerMove: (e) {
            if (_down == null) return;
            if ((e.position - _down!).distanceSquared > 20 * 20) {
              _moved = true;
            }
          },
          onPointerUp: (_) {
            if (!_moved) _openFocus();
            _down = null;
            _moved = false;
          },
          onPointerCancel: (_) {
            _down = null;
            _moved = false;
          },
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _snapToNearest();
              });
              return false;
            },
            child: ListView.builder(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: sidePad),
              itemExtent: extent,
              itemCount: items.length,
              itemBuilder: (_, _) => const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }

  /// Fester Bogen: x linear, y nach unten versetzt je weiter vom Fokus.
  /// → gleitet seitwärts, dreht sich nicht um eine Achse.
  Widget _coverflowItem(
    HubArcItem item, {
    required int i,
    required double offset,
    required double focusY,
    required double stepX,
    required double arcDrop,
    required double itemSize,
    required double boxH,
    required Size viewport,
  }) {
    final dist = i - offset;
    final ad = dist.abs();
    final visible = ad <= 2.8;

    // Parabel-Bogen: Fokus oben, Nachbarn tiefer (Halbkreis-Look).
    final t = (ad / 2.2).clamp(0.0, 1.0);
    final x = viewport.width / 2 + dist * stepX;
    final y = focusY + arcDrop * (t * t);

    final focus = 1.0 - (ad / 1.35).clamp(0.0, 1.0);
    final scale = 0.72 + 0.28 * focus;
    final opacity = visible ? (0.40 + 0.60 * focus) : 0.0;

    final top = (y - itemSize / 2).clamp(0.0, viewport.height - boxH);
    final left = x - itemSize / 2;

    // Immer im Tree lassen (Offstage) — sonst springt die Diashow beim Scrollen.
    return Positioned(
      left: left,
      top: top,
      width: itemSize,
      height: boxH,
      child: Offstage(
        offstage: !visible,
        child: IgnorePointer(
          ignoring: !visible,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: BaubleHubPortal(
                key: ValueKey('bauble_${item.id}'),
                title: item.title,
                subtitle: item.subtitle,
                coverAsset: item.coverAsset,
                coverAssets: item.coverAssets,
                frame: item.frame,
                badge: item.badge,
                slideOffset: item.slideOffset,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
