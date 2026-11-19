import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/asset_precache.dart';
import '../utils/image_source.dart';

enum BaubleFrameColor { gold, red, green }

/// Rundes Hub-Portal mit Weihnachtskugel-Rahmen-Overlay (+ optionale Diashow).
class BaubleHubPortal extends StatefulWidget {
  const BaubleHubPortal({
    super.key,
    required this.title,
    required this.frame,
    required this.onTap,
    this.coverAsset,
    this.coverAssets,
    this.subtitle,
    this.badge,
    this.slideOffset = Duration.zero,
  });

  final String title;
  final String? subtitle;
  final String? coverAsset;
  final List<String>? coverAssets;
  final BaubleFrameColor frame;
  final String? badge;
  final VoidCallback onTap;
  final Duration slideOffset;

  static String frameAsset(BaubleFrameColor color) => switch (color) {
        BaubleFrameColor.gold => 'assets/images/hub_bauble_frame_gold.png',
        BaubleFrameColor.red => 'assets/images/hub_bauble_frame_red.png',
        BaubleFrameColor.green => 'assets/images/hub_bauble_frame_green.png',
      };

  @override
  State<BaubleHubPortal> createState() => _BaubleHubPortalState();
}

class _BaubleHubPortalState extends State<BaubleHubPortal> {
  static const _slideInterval = Duration(milliseconds: 3600);
  static const _fadeDuration = Duration(milliseconds: 850);

  int _index = 0;
  int _slideGen = 0;
  Timer? _timer;
  Timer? _startDelay;
  int? _cacheWidth;
  bool _warmed = false;

  List<String> get _slides {
    final multi = widget.coverAssets;
    if (multi != null && multi.isNotEmpty) {
      final filtered = [
        for (final p in multi)
          if (p.isNotEmpty && isLocalImageAvailable(p)) p,
      ];
      if (filtered.isNotEmpty) return filtered;
    }
    final single = widget.coverAsset;
    if (single != null &&
        single.isNotEmpty &&
        isLocalImageAvailable(single)) {
      return [single];
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _startDelay = Timer(widget.slideOffset, _startSlideshow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheWidth ??=
        thumbCacheWidth(context, MediaQuery.sizeOf(context).shortestSide * 0.4);
    if (_warmed) return;
    _warmed = true;
    _warmAround(_index);
  }

  @override
  void didUpdateWidget(covariant BaubleHubPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nur bei inhaltlicher Änderung neu starten — nicht bei neuer List-Instanz.
    if (!_sameSlides(oldWidget.coverAssets, widget.coverAssets) ||
        oldWidget.coverAsset != widget.coverAsset) {
      _index = 0;
      _slideGen = 0;
      _timer?.cancel();
      _startDelay?.cancel();
      _startDelay = Timer(widget.slideOffset, _startSlideshow);
    }
  }

  bool _sameSlides(List<String>? a, List<String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _warmAround(int index) {
    final assets = _slides;
    if (assets.isEmpty) return;
    final paths = <String>{
      assets[index % assets.length],
    };
    if (assets.length > 1) {
      // Nächstes zufälliges Bild vorwärmen (nicht strikt Folgeindex).
      final guess = math.Random().nextInt(assets.length);
      paths.add(assets[guess]);
    }
    unawaited(precacheAssetImages(context, paths, cacheWidth: _cacheWidth));
  }

  void _startSlideshow() {
    if (!mounted || _slides.length < 2) return;
    _timer?.cancel();
    _timer = Timer.periodic(_slideInterval, (_) {
      if (!mounted) return;
      final assets = _slides;
      if (assets.length < 2) return;
      final currentPath = assets[_index.clamp(0, assets.length - 1)];
      // Zufälliges anderes Bild (anderer Pfad → keine Duplicate Keys).
      var next = math.Random().nextInt(assets.length);
      for (var i = 0; i < assets.length; i++) {
        final candidate = (next + i) % assets.length;
        if (assets[candidate] != currentPath) {
          next = candidate;
          break;
        }
      }
      _warmAround(next);
      setState(() {
        _index = next;
        _slideGen++;
      });
    });
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final current = slides.isEmpty
        ? ''
        : slides[_index.clamp(0, slides.length - 1)];

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final side = mathMin(c.maxWidth, c.maxHeight);
                return Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            side * 0.13,
                            side * 0.18,
                            side * 0.13,
                            side * 0.09,
                          ),
                          child: ClipOval(
                            child: AnimatedSwitcher(
                              duration: _fadeDuration,
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              child: SizedBox.expand(
                                // Generations-Key: verhindert Duplicate Keys beim Fade.
                                key: ValueKey<String>('$_slideGen:$current'),
                                child: current.isEmpty
                                    ? ColoredBox(
                                        color: const Color(0xFF1A3355),
                                        child: Icon(
                                          Icons.auto_awesome,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          size: side * 0.22,
                                        ),
                                      )
                                    : Image(
                                        image: ResizeImage.resizeIfNeeded(
                                          _cacheWidth,
                                          null,
                                          imageProviderFor(current),
                                        ),
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                        gaplessPlayback: false,
                                        filterQuality: FilterQuality.medium,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        Image.asset(
                          BaubleHubPortal.frameAsset(widget.frame),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        if (widget.badge != null && widget.badge!.isNotEmpty)
                          Positioned(
                            right: side * 0.06,
                            top: side * 0.12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white70),
                              ),
                              child: Text(
                                widget.badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              shadows: [
                Shadow(blurRadius: 6, color: Colors.black54),
              ],
            ),
          ),
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

double mathMin(double a, double b) => a < b ? a : b;
