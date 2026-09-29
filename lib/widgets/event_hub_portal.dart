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
  });

  final String title;
  final String? subtitle;
  final List<String> imagePaths;
  final Color accent;
  final VoidCallback onTap;
  final Duration slideOffset;
  final bool isHalloween;

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
                          : Image(
                              image: ResizeImage.resizeIfNeeded(
                                _cacheWidth,
                                null,
                                imageProviderFor(current),
                              ),
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.15),
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: widget.accent.withValues(alpha: 0.35),
                              ),
                            ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.58),
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

    return GalleryFrame(
      style: GalleryFrameStyle.halloween,
      showHalloweenBadge: false,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          portal,
          // Kürbis oben links
          const Positioned(
            left: 6,
            top: 6,
            child: _EmojiChip('🎃', fontSize: 18),
          ),
          // Fledermaus oben rechts
          const Positioned(
            right: 6,
            top: 6,
            child: _EmojiChip('🦇', fontSize: 17),
          ),
          // Spinne unten links
          const Positioned(
            left: 6,
            bottom: 6,
            child: _EmojiChip('🕷️', fontSize: 16),
          ),
          // Kleine Fledermaus unten rechts
          const Positioned(
            right: 8,
            bottom: 8,
            child: _EmojiChip('🦇', fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  const _EmojiChip(this.emoji, {this.fontSize = 16});

  final String emoji;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD56A).withValues(alpha: 0.75),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C42).withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          emoji,
          style: TextStyle(fontSize: fontSize, height: 1.1),
        ),
      ),
    );
  }
}
