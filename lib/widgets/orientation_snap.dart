import 'dart:async';

import 'package:flutter/widgets.dart';

/// Sauberer Dreh-Cut: während Zwischengrößen nur Coverfarbe —
/// kein verzogenes Layout, kein Bild-Stretch.
class OrientationSnap extends StatefulWidget {
  const OrientationSnap({
    super.key,
    required this.child,
    this.coverColor = const Color(0xFF12263F),
  });

  final Widget child;
  final Color coverColor;

  @override
  State<OrientationSnap> createState() => _OrientationSnapState();
}

class _OrientationSnapState extends State<OrientationSnap>
    with WidgetsBindingObserver {
  bool? _landscape;
  bool _covering = false;
  Timer? _revealTimer;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _landscape = _physicalLandscape();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool? _physicalLandscape() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return null;
    final size = views.first.physicalSize;
    if (size.width <= 0 || size.height <= 0) return null;
    return size.width >= size.height;
  }

  static bool _isAmbiguous(Size size) {
    if (size.width <= 0 || size.height <= 0) return false;
    final ratio = size.width / size.height;
    return ratio > 0.86 && ratio < 1.16;
  }

  void _coverUntilSettled() {
    final epoch = ++_epoch;
    _revealTimer?.cancel();
    if (!_covering) {
      setState(() => _covering = true);
    }
    // Kurz halten, bis OS + Flutter die Endgröße geliefert haben.
    _revealTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || epoch != _epoch) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || epoch != _epoch) return;
        if (_covering) setState(() => _covering = false);
      });
    });
  }

  @override
  void didChangeMetrics() {
    final next = _physicalLandscape();
    if (next == null) return;
    if (_landscape != null && next != _landscape) {
      _landscape = next;
      _coverUntilSettled();
      return;
    }
    _landscape = next;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ambiguous = _isAmbiguous(size);
    if (!ambiguous && size.width > 0 && size.height > 0) {
      _landscape = size.width >= size.height;
    }

    final hide = _covering || ambiguous;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (hide)
          Positioned.fill(
            child: ColoredBox(color: widget.coverColor),
          ),
      ],
    );
  }
}
