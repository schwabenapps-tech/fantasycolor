import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_layout.dart';
import '../utils/asset_precache.dart';
import '../utils/image_source.dart';
import 'event_badges.dart';

/// Diashow-Portal wie im Start-Hub — für Event-Kategorien in den Galerien.
class EventHubPortal extends StatefulWidget {
  const EventHubPortal({
    super.key,
    required this.title,
    required this.imagePaths,
    required this.onTap,
    this.accent = const Color(0xFFFF8C42),
    this.subtitle,
    this.slideOffset = Duration.zero,
    this.isHalloween = false,
    this.showPumpkinEmoji = false,
    this.brightenImage = false,
  });

  final String title;
  final String? subtitle;
  final List<String> imagePaths;
  final Color accent;
  final VoidCallback onTap;
  final Duration slideOffset;
  final bool isHalloween;
  final bool showPumpkinEmoji;
  /// Etwas helleres Vorschaubild (z. B. Start-Hub Event).
  final bool brightenImage;

  @override
  State<EventHubPortal> createState() => _EventHubPortalState();
}

class _EventHubPortalState extends State<EventHubPortal> {
  static const _slideInterval = Duration(milliseconds: 3800);
  static const _fadeDuration = Duration(milliseconds: 900);

  bool _pressed = false;
  int _index = 0;
  Timer? _timer;
  Timer? _startDelay;
  int? _cacheWidth;

  @override
  void initState() {
    super.initState();
    _startDelay = Timer(widget.slideOffset, _startSlideshow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheWidth ??=
        thumbCacheWidth(context, MediaQuery.sizeOf(context).shortestSide * 0.45);
    _warmAround(_index);
  }

  void _warmAround(int index) {
    final assets = widget.imagePaths;
    if (assets.isEmpty) return;
    final paths = <String>{
      assets[index % assets.length],
      assets[(index + 1) % assets.length],
    };
    unawaited(precacheAssetImages(context, paths, cacheWidth: _cacheWidth));
  }

  void _startSlideshow() {
    if (!mounted || widget.imagePaths.length < 2) return;
    _timer?.cancel();
    _timer = Timer.periodic(_slideInterval, (_) {
      if (!mounted) return;
      final next = (_index + 1) % widget.imagePaths.length;
      _warmAround(next);
      setState(() => _index = next);
    });
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildPreviewImage(String path) {
    final image = Image(
      image: ResizeImage.resizeIfNeeded(
        _cacheWidth,
        null,
        imageProviderFor(path),
      ),
      fit: BoxFit.cover,
      alignment: widget.imagePaths.length == 1
          ? Alignment.center
          : const Alignment(0, -0.15),
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => ColoredBox(
        color: widget.accent.withValues(alpha: 0.35),
      ),
    );
    if (!widget.brightenImage) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1.18, 0, 0, 0, 22,
        0, 1.18, 0, 0, 22,
        0, 0, 1.18, 0, 22,
        0, 0, 0, 1, 0,
      ]),
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final assets = widget.imagePaths;
    final current = assets.isEmpty
        ? ''
        : assets[_index.clamp(0, assets.length - 1)];
    final layout = AppLayout.of(context);
    final halloween = widget.isHalloween;

    final portal = Semantics(
      button: true,
      label: widget.title,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: _fadeDuration,
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          ...previousChildren,
                          ?currentChild,
                        ],
                      );
                    },
                    child: SizedBox.expand(
                      key: ValueKey<String>(current),
                      child: current.isEmpty
                          ? ColoredBox(
                              color: widget.accent.withValues(alpha: 0.35),
                            )
                          : _buildPreviewImage(current),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(
                          alpha: widget.brightenImage ? 0.0 : 0.05,
                        ),
                        Colors.black.withValues(
                          alpha: widget.brightenImage ? 0.32 : 0.58,
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: layout.isTablet ? 26 : 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!halloween) {
      return GalleryFrame(
        style: GalleryFrameStyle.fantasy,
        showHalloweenBadge: false,
        child: portal,
      );
    }

    // Rahmen etwas eingerückt; große Emojis sitzen als Overlay auf den Ecken.
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 10,
          top: 12,
          right: 10,
          bottom: 12,
          child: GalleryFrame(
            style: GalleryFrameStyle.halloween,
            showHalloweenBadge: false,
            child: portal,
          ),
        ),
        if (widget.showPumpkinEmoji)
          const Positioned(
            left: 0,
            top: 0,
            child: _FrameEmoji('🎃', size: 36),
          ),
      ],
    );
  }
}

class _FrameEmoji extends StatelessWidget {
  const _FrameEmoji(this.emoji, {required this.size});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: size,
          height: 1,
          shadows: const [
            Shadow(
              color: Color(0xCC000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
            Shadow(
              color: Color(0x66FF8C42),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}
