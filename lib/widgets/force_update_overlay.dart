import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../services/store_config.dart';

/// Vollflächiges, nicht schließbares Update-Overlay.
class ForceUpdateOverlay extends StatefulWidget {
  const ForceUpdateOverlay({
    super.key,
    required this.message,
  });

  final String message;

  @override
  State<ForceUpdateOverlay> createState() => _ForceUpdateOverlayState();
}

class _ForceUpdateOverlayState extends State<ForceUpdateOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _sparkle;
  late final AnimationController _bounce;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _bounceScale;
  bool _openingStore = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOutBack),
    );
    _bounceScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _bounce, curve: Curves.easeInOut),
    );

    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _sparkle.dispose();
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _openStore() async {
    if (_openingStore) return;
    setState(() => _openingStore = true);
    HapticFeedback.lightImpact();
    final primary =
        Platform.isIOS ? StoreConfig.appStoreUri : StoreConfig.playStoreUri;
    try {
      await launchUrl(primary, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      debugPrint('ForceUpdateOverlay openStore failed: $e\n$st');
      if (Platform.isIOS) {
        try {
          await launchUrl(
            StoreConfig.appStoreReviewUri,
            mode: LaunchMode.externalApplication,
          );
        } catch (e2, st2) {
          debugPrint('ForceUpdateOverlay review fallback failed: $e2\n$st2');
        }
      }
    } finally {
      if (mounted) setState(() => _openingStore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final titleSize = shortest < 360 ? 26.0 : 32.0;
    final bodySize = shortest < 360 ? 14.0 : 16.0;

    return PopScope(
      canPop: false,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _sparkle, _bounce]),
        builder: (context, _) {
          return Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: const Color(0xFF1A0B2E).withValues(
                    alpha: 0.88 * _fade.value,
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ForceSparklePainter(
                      progress: _sparkle.value,
                      intensity: _fade.value,
                    ),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: _fade.value,
                    child: Transform.scale(
                      scale: _scale.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF6B3FA0),
                                  Color(0xFF3D1F6E),
                                  Color(0xFF2A1450),
                                ],
                              ),
                              border: Border.all(
                                color: const Color(0xFFE8B4FF)
                                    .withValues(alpha: 0.75),
                                width: 2.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFB07CFF)
                                      .withValues(alpha: 0.45),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                                const BoxShadow(
                                  color: Color(0x88000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                26,
                                22,
                                22,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.system_update_rounded,
                                    size: titleSize * 0.95,
                                    color: const Color(0xFFFFE27A),
                                    shadows: const [
                                      Shadow(
                                        color: Color(0xFFB07CFF),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    t.updateRequired,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFFFFE8FF),
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                      letterSpacing: 0.4,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0xFFB07CFF),
                                          blurRadius: 16,
                                        ),
                                        Shadow(
                                          color: Color(0xAA000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    widget.message.isNotEmpty
                                        ? widget.message
                                        : t.forceUpdateMessage,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFFE8D4FF)
                                          .withValues(alpha: 0.95),
                                      fontSize: bodySize,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      letterSpacing: 0.2,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  ScaleTransition(
                                    scale: _bounceScale,
                                    child: _UpdateStoreButton(
                                      busy: _openingStore,
                                      label: t.updateNow,
                                      onPressed: () =>
                                          unawaited(_openStore()),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UpdateStoreButton extends StatefulWidget {
  const _UpdateStoreButton({
    required this.onPressed,
    required this.busy,
    required this.label,
  });

  final VoidCallback onPressed;
  final bool busy;
  final String label;

  @override
  State<_UpdateStoreButton> createState() => _UpdateStoreButtonState();
}

class _UpdateStoreButtonState extends State<_UpdateStoreButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown:
            widget.busy ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.busy
            ? null
            : (_) {
                setState(() => _pressed = false);
                widget.onPressed();
              },
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 100),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFE27A),
                  Color(0xFFFFB84D),
                  Color(0xFFFF8C42),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFF1B0),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB84D).withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                const BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              child: widget.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFF3A1848),
                      ),
                    )
                  : Text(
                      widget.label,
                      style: const TextStyle(
                        color: Color(0xFF3A1848),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForceSparklePainter extends CustomPainter {
  _ForceSparklePainter({
    required this.progress,
    required this.intensity,
  });

  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.01) return;
    final rnd = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 28; i++) {
      final x = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final drift = ((progress + i * 0.07) % 1.0);
      final y = (baseY + drift * size.height * 0.15) % size.height;
      final twinkle =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin((progress * 6 + i) * math.pi));
      paint.color = Color.lerp(
        const Color(0xFFE8B4FF),
        const Color(0xFFFFF6C8),
        rnd.nextDouble(),
      )!
          .withValues(alpha: 0.55 * intensity * twinkle);
      canvas.drawCircle(Offset(x, y), 1.6 + rnd.nextDouble() * 2.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForceSparklePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}
