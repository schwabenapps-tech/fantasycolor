import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import 'star_balance_pill.dart';

/// Gemeinsame Level-Complete-Ansicht: Fade-in, Konfetti, fliegende Sterne, Buttons.
class LevelCompleteOverlay extends StatefulWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.title,
    required this.actions,
    this.ratingStars = 0,
    this.earnedStars = 0,
    this.fallbackSubtitle,
    this.onReady,
  });

  final String title;

  /// 1–3 Qualitäts-Sterne, die nacheinander hochfliegen.
  final int ratingStars;

  /// Verdiente Wallet-Sterne (+N). 0 = keine Anzeige (z.B. Daily-Aufgabe).
  final int earnedStars;

  /// Wenn weder Rating noch Earn: Fallback-Text.
  final String? fallbackSubtitle;

  final List<Widget> actions;

  /// Nach Fade-in + Stern-Flug + Earn-Count (Buttons sichtbar).
  final VoidCallback? onReady;

  @override
  State<LevelCompleteOverlay> createState() => LevelCompleteOverlayState();
}

class LevelCompleteOverlayState extends State<LevelCompleteOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fade;
  late final AnimationController _confetti;
  late final AnimationController _stars;
  late final AnimationController _earn;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _earnAnim;
  bool _showActions = false;
  bool _showEarn = false;
  bool _dismissing = false;

  int get _rating => widget.ratingStars.clamp(0, 3);
  int get _earned => widget.earnedStars.clamp(0, 999);

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    final starMs = _rating <= 0 ? 1 : (520 + _rating * 480);
    _stars = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: starMs),
    );
    _earn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fadeAnim = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);
    _scaleAnim = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _fade, curve: Curves.easeOutBack),
    );
    _earnAnim = CurvedAnimation(parent: _earn, curve: Curves.easeOutCubic);
    _runIntro();
  }

  Future<void> _runIntro() async {
    await _fade.forward();
    if (!mounted) return;

    // Immer zuerst die Qualitäts-Sterne hochfliegen.
    if (_rating > 0) {
      await _stars.forward();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
    }

    // Danach verdiente Sterne hochzählen + Text.
    if (_earned > 0) {
      setState(() => _showEarn = true);
      HapticFeedback.lightImpact();
      await _earn.forward();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
    }

    setState(() => _showActions = true);
    widget.onReady?.call();
  }

  /// Sanft ausblenden, dann [true] zurückgeben.
  Future<void> fadeOut() async {
    if (_dismissing) return;
    _dismissing = true;
    if (mounted) setState(() => _showActions = false);
    await _fade.reverse();
  }

  @override
  void dispose() {
    _fade.dispose();
    _confetti.dispose();
    _stars.dispose();
    _earn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final topPad = landscape ? size.height * 0.14 : size.height * 0.12;
    final tStrings = AppStrings.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_fade, _confetti, _stars, _earn]),
      builder: (context, _) {
        final t = _fadeAnim.value;
        final earnCount = _showEarn
            ? (_earned * _earnAnim.value).round().clamp(0, _earned)
            : 0;
        final earnOpacity = _showEarn ? _earnAnim.value.clamp(0.0, 1.0) : 0.0;

        return Opacity(
          opacity: t,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.42 * t),
              ),
              IgnorePointer(
                child: _ConfettiRain(
                  progress: _confetti.value,
                  intensity: t,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: topPad,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFD56A),
                          fontSize: landscape ? 34 : 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFFD56A)
                                  .withValues(alpha: 0.55),
                              blurRadius: 18,
                            ),
                            const Shadow(
                              color: Color(0xAA000000),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      // Platzhalter: Abstand Titel → Sterne (Flug im Fullscreen-Layer).
                      if (_rating > 0)
                        SizedBox(height: landscape ? 118 : 132),
                      if (_earned > 0) ...[
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: earnOpacity,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - earnOpacity)),
                            child: Transform.scale(
                              scale: 0.88 + 0.12 * earnOpacity,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+$earnCount',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFFFFF4C8),
                                      fontSize: landscape ? 36 : 42,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                      shadows: [
                                        Shadow(
                                          color: const Color(0xFFFFD56A)
                                              .withValues(alpha: 0.5),
                                          blurRadius: 16,
                                        ),
                                        const Shadow(
                                          color: Color(0xAA000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tStrings.youEarnedStars(earnCount),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.92),
                                      fontSize: landscape ? 15 : 16,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0xAA000000),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else if (_rating <= 0 &&
                          (widget.fallbackSubtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          widget.fallbackSubtitle!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ],
                      AnimatedOpacity(
                        opacity: _showActions ? 1 : 0,
                        duration: const Duration(milliseconds: 280),
                        child: IgnorePointer(
                          ignoring: !_showActions,
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: landscape ? 56 : 72,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0;
                                    i < widget.actions.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  widget.actions[i],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_rating > 0)
                IgnorePointer(
                  child: _FlyingRatingStars(
                    count: _rating,
                    progress: _stars.value,
                    landY: topPad + (landscape ? 92 : 108),
                    screenSize: size,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Sterne fliegen nacheinander vom unteren Rand unter den Titel.
class _FlyingRatingStars extends StatelessWidget {
  const _FlyingRatingStars({
    required this.count,
    required this.progress,
    required this.landY,
    required this.screenSize,
  });

  final int count;
  final double progress;
  final double landY;
  final Size screenSize;

  static const _starSize = 92.0;
  static const _gap = 16.0;

  @override
  Widget build(BuildContext context) {
    final rowWidth = count * _starSize + (count - 1) * _gap;
    final originX = (screenSize.width - rowWidth) / 2;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < count; i++)
          _buildStar(i, originX),
      ],
    );
  }

  Widget _buildStar(int index, double originX) {
    final slot = 1.0 / count;
    final start = index * slot * 0.92;
    final local = ((progress - start) / (slot * 0.88)).clamp(0.0, 1.0);
    final fly = Curves.easeOutBack.transform(local);
    final settled = local >= 0.98;

    final targetX = originX + index * (_starSize + _gap);
    final startY = screenSize.height + _starSize;
    final y = startY + (landY - startY) * fly;
    final spin = settled ? 0.0 : (1.0 - fly) * math.pi * 3.0;

    final opacity = local <= 0 ? 0.0 : (local * 3).clamp(0.0, 1.0);
    final scale = 0.55 + 0.45 * fly;

    return Positioned(
      left: targetX,
      top: y,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: spin,
          child: Transform.scale(
            scale: scale,
            child: Image.asset(
              StarBalancePill.asset,
              width: _starSize,
              height: _starSize,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiRain extends StatelessWidget {
  const _ConfettiRain({
    required this.progress,
    required this.intensity,
  });

  final double progress;
  final double intensity;

  static const _colors = <Color>[
    Color(0xFFFFD56A),
    Color(0xFFFF85A1),
    Color(0xFFC9A6FF),
    Color(0xFF6EE0FF),
    Color(0xFFB6F5C8),
    Color(0xFFFFB347),
    Color(0xFFFF6B9D),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: List.generate(42, (i) {
        final seed = i * 19.7;
        final x = ((math.sin(seed) * 0.5 + 0.5) + i * 0.017) % 1.0;
        final speed = 0.55 + (i % 7) * 0.08;
        final drift = math.sin(progress * math.pi * 2 + seed) * 18;
        final y = ((progress * speed) + (i * 0.07)) % 1.15 - 0.08;
        final pieceSize = 5.0 + (i % 5) * 2.4;
        final spin = progress * (4 + i % 5) + seed;
        final opacity =
            (intensity * (0.55 + (i % 4) * 0.1)).clamp(0.0, 0.95);

        return Positioned(
          left: size.width * x + drift,
          top: size.height * y,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: spin,
              child: i.isEven
                  ? Icon(
                      Icons.auto_awesome_rounded,
                      size: pieceSize,
                      color: _colors[i % _colors.length],
                    )
                  : Container(
                      width: pieceSize * 0.7,
                      height: pieceSize * 1.15,
                      decoration: BoxDecoration(
                        color: _colors[i % _colors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
            ),
          ),
        );
      }),
    );
  }
}

/// Spieliger Aktions-Button mit Press-Bounce (kein Material-Ripple).
class LevelCompleteActionButton extends StatefulWidget {
  const LevelCompleteActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  /// Hero-CTA: breiter, höher, stärkerer Schatten.
  final bool prominent;

  @override
  State<LevelCompleteActionButton> createState() =>
      _LevelCompleteActionButtonState();
}

class _LevelCompleteActionButtonState extends State<LevelCompleteActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _press.forward();

  void _onTapCancel() => _press.reverse();

  Future<void> _onTapUp(TapUpDetails _) async {
    await _press.reverse();
    if (!mounted) return;
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.prominent ? 56.0 : 48.0;
    final fontSize = widget.prominent ? 16.0 : 15.0;
    final radius = widget.prominent ? 18.0 : 16.0;

    return AnimatedBuilder(
      animation: _press,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_press.value);
        final scale = 1.0 - 0.08 * t;
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: SizedBox(
          width: widget.prominent ? double.infinity : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: widget.filled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF0C2),
                        Color(0xFFFFD56A),
                        Color(0xFFE0A93A),
                      ],
                    )
                  : null,
              color: widget.filled ? null : const Color(0xFF2A3D58),
              border: Border.all(
                color: widget.filled
                    ? const Color(0xFFFFE7A0)
                    : Colors.white.withValues(alpha: 0.72),
                width: widget.filled ? 1.2 : 1.5,
              ),
              boxShadow: widget.filled
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD56A).withValues(
                          alpha: widget.prominent ? 0.5 : 0.35,
                        ),
                        blurRadius: widget.prominent ? 18 : 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.prominent ? 20 : 16,
                ),
                child: Row(
                  mainAxisSize: widget.prominent
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: widget.prominent ? 22 : 20,
                      color: widget.filled
                          ? const Color(0xFF3A2810)
                          : Colors.white.withValues(alpha: 0.92),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        maxLines: widget.prominent ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.filled
                              ? const Color(0xFF3A2810)
                              : Colors.white.withValues(alpha: 0.95),
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
