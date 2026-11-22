import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'star_balance_pill.dart';

/// Stern fliegt von unten in die Mitte, dreht sich, +N und Gesamtzahl zählen hoch.
class StarEarnOverlay {
  StarEarnOverlay._();

  static Future<void> show(
    BuildContext context, {
    required int amount,
    int? newTotal,
  }) {
    if (amount <= 0) return Future<void>.value();
    HapticFeedback.mediumImpact();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => _StarEarnBody(
        amount: amount,
        newTotal: newTotal,
        onDone: () => Navigator.of(ctx).maybePop(),
      ),
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
}

class _StarEarnBody extends StatefulWidget {
  const _StarEarnBody({
    required this.amount,
    required this.onDone,
    this.newTotal,
  });

  final int amount;
  final int? newTotal;
  final VoidCallback onDone;

  @override
  State<_StarEarnBody> createState() => _StarEarnBodyState();
}

class _StarEarnBodyState extends State<_StarEarnBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    unawaited(_run());
  }

  Future<void> _run() async {
    await _ctrl.forward();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || _closing) return;
    _closing = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final centerY = size.height * 0.42;
    final startY = size.height + 48;
    final starSize = math.min(168.0, size.width * 0.40);
    final totalTo = widget.newTotal;
    final totalFrom =
        totalTo == null ? null : (totalTo - widget.amount).clamp(0, totalTo);

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          // 0–0.48: Flug + Drehung
          final flyT = Curves.easeOutCubic.transform(
            (t / 0.48).clamp(0.0, 1.0),
          );
          final y = startY + (centerY - startY) * flyT;
          final spin = t * math.pi * 5.2;
          final starScale = 0.55 + 0.45 * flyT;

          // Ab ~0.5: Count-up
          final countT = Curves.easeOutCubic.transform(
            ((t - 0.5) / 0.38).clamp(0.0, 1.0),
          );
          final shown = (widget.amount * countT).round();
          final showCount = t >= 0.48;
          final shownTotal = totalFrom == null || totalTo == null
              ? null
              : (totalFrom + (totalTo - totalFrom) * countT).round();

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: y - starSize / 2,
                child: Center(
                  child: Transform.rotate(
                    angle: spin,
                    child: Transform.scale(
                      scale: starScale,
                      child: Image.asset(
                        StarBalancePill.asset,
                        width: starSize,
                        height: starSize,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ),
              if (showCount)
                Positioned(
                  left: 0,
                  right: 0,
                  top: centerY + starSize * 0.55,
                  child: Opacity(
                    opacity: countT.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * countT,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+$shown',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFFFD56A),
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFFFFD56A)
                                      .withValues(alpha: 0.55),
                                  blurRadius: 22,
                                ),
                                const Shadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          if (shownTotal != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  StarBalancePill.asset,
                                  width: 28,
                                  height: 28,
                                  filterQuality: FilterQuality.high,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$shownTotal',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0xAA000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
