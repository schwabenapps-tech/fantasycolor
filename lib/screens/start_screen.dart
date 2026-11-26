import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'hub_screen.dart';
import '../l10n/app_strings.dart';
import '../services/audio_service.dart';
import '../services/deep_link_service.dart';
import '../services/remote_pack_service.dart';
import '../utils/app_orientations.dart';
import '../utils/app_page_route.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  static const _portraitAsset = 'assets/images/splash_portrait.png';

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    unawaited(AppOrientations.lockHubPortrait());
    // Musik schon auf dem Startscreen — Signal, dass die App bereit ist.
    unawaited(AudioService.instance.startAmbient());
    // Pack-Sync früh anstoßen, damit Vorladen auf dem Splash sichtbar wird.
    unawaited(RemotePackService.instance.sync());
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
    // App-Store-Event / Custom-URL: direkt in den Hub.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(precacheImage(const AssetImage(_portraitAsset), context));
      if (DeepLinkService.instance.consumePendingOpenHub()) {
        unawaited(_enterHub());
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _enterHub() async {
    await AppOrientations.lockHubPortrait();
    unawaited(AudioService.instance.startAmbient());
    if (!mounted) return;
    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => const HubScreen(),
      ),
    );
    if (mounted) unawaited(AppOrientations.lockHubPortrait());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Hintergrund sofort voll sichtbar — kein Fade von 0 (sonst schwarzer Flash).
    return Scaffold(
      backgroundColor: const Color(0xFF12263F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Portrait-Asset: cover + clip — kein Strecken in die Breite.
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF12263F),
              child: Image.asset(
                _portraitAsset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Align(
                alignment: const Alignment(0, 0.72),
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: FantasyPlayButton(
                    size: size.shortestSide * 0.26,
                    onPressed: () => unawaited(_enterHub()),
                  ),
                ),
              ),
            ),
          ),
          const _PackPreloadBanner(),
        ],
      ),
    );
  }
}

/// Kurzes Vorladen, nur wenn ein Remote-Pack wirklich heruntergeladen wird.
class _PackPreloadBanner extends StatelessWidget {
  const _PackPreloadBanner();

  @override
  Widget build(BuildContext context) {
    final packs = context.watch<RemotePackService>();
    if (!packs.isDownloading) return const SizedBox.shrink();
    final t = AppStrings.of(context);
    final progress = packs.downloadProgress;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1A334F).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE8D5A3).withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.packDownloadTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFF6E4),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.packDownloadHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFE8D5A3).withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress <= 0 ? null : progress,
                      minHeight: 6,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.12),
                      color: const Color(0xFFFFD56A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Silberner Fantasy-Play-Button — erhaben, mit Schlagschatten und Metallglanz.
class FantasyPlayButton extends StatefulWidget {
  const FantasyPlayButton({
    super.key,
    required this.onPressed,
    this.size = 88,
  });

  final VoidCallback onPressed;
  final double size;

  @override
  State<FantasyPlayButton> createState() => _FantasyPlayButtonState();
}

class _FantasyPlayButtonState extends State<FantasyPlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // Extra Platz für Glow + Drop-Shadow (sonst wirkt der Knopf flach/abgeschnitten).
    final pad = size * 0.22;

    return Semantics(
      button: true,
      label: 'Play',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: SizedBox(
            width: size + pad * 2,
            height: size + pad * 2,
            child: CustomPaint(
              painter: _FantasyPlayPainter(pressed: _pressed),
            ),
          ),
        ),
      ),
    );
  }
}

class _FantasyPlayPainter extends CustomPainter {
  _FantasyPlayPainter({required this.pressed});

  final bool pressed;

  static const _gemColors = [
    Color(0xFF5EB7FF),
    Color(0xFFB07CFF),
    Color(0xFF6EE0FF),
    Color(0xFF9B6CFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - size.height * 0.02);
    final radius = size.shortestSide * 0.36;

    _drawFloorShadow(canvas, center, radius);
    _drawAura(canvas, center, radius);
    _drawMetalDisc(canvas, center, radius);
    _drawBevelRing(canvas, center, radius);
    _drawFiligreeRing(canvas, center, radius);
    _drawInnerWell(canvas, center, radius);
    _drawGems(canvas, center, radius);
    _drawPlayTriangle(canvas, center, radius);
    _drawCrestCrystal(canvas, center, radius);
    if (!pressed) _drawTopSpecular(canvas, center, radius);
  }

  void _drawFloorShadow(Canvas canvas, Offset center, double radius) {
    final lift = pressed ? 0.35 : 1.0;
    final shadowCenter = center.translate(0, radius * (0.18 + 0.1 * lift));
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter,
        width: radius * (1.7 + 0.15 * lift),
        height: radius * (0.38 + 0.12 * lift),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42 * lift)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.22),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter.translate(0, radius * 0.02),
        width: radius * 1.15,
        height: radius * 0.22,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28 * lift)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.08),
    );
  }

  void _drawAura(Canvas canvas, Offset center, double radius) {
    final a = pressed ? 0.55 : 1.0;
    canvas.drawCircle(
      center,
      radius * 1.18,
      Paint()
        ..color = const Color(0xFFA8D4FF).withValues(alpha: 0.28 * a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.35),
    );
    canvas.drawCircle(
      center,
      radius * 1.02,
      Paint()
        ..color = const Color(0xFFC9A6FF).withValues(alpha: 0.16 * a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.22),
    );
  }

  void _drawMetalDisc(Canvas canvas, Offset center, double radius) {
    final r = radius * 0.96;
    final rect = Rect.fromCircle(center: center, radius: r);

    // Unterer „Dicke“-Rand (erhabener Metallkörper).
    canvas.drawCircle(
      center.translate(0, radius * (pressed ? 0.018 : 0.045)),
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.15, 0.55),
          radius: 1.05,
          colors: [
            const Color(0xFF6A7386),
            const Color(0xFF3A4252),
            Color(0xFF1A1F2A).withValues(alpha: 0.95),
          ],
        ).createShader(rect.shift(Offset(0, radius * 0.04))),
    );

    // Obere Metallfläche mit Licht von oben-links.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(pressed ? -0.15 : -0.45, pressed ? -0.2 : -0.55),
          radius: 1.15,
          colors: pressed
              ? const [
                  Color(0xFFE8ECF4),
                  Color(0xFFB0B8C8),
                  Color(0xFF7A8496),
                  Color(0xFF525A6A),
                ]
              : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFE8EEF8),
                  Color(0xFFB8C2D4),
                  Color(0xFF7E879A),
                  Color(0xFF5A6476),
                ],
          stops: pressed
              ? const [0.0, 0.35, 0.7, 1.0]
              : const [0.0, 0.22, 0.5, 0.78, 1.0],
        ).createShader(rect),
    );

    // Leichter Sweep für gebürstetes Metall.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..blendMode = BlendMode.softLight
        ..shader = SweepGradient(
          startAngle: -0.8,
          endAngle: math.pi * 2 - 0.8,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.25),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.4),
          ],
        ).createShader(rect),
    );
  }

  void _drawBevelRing(Canvas canvas, Offset center, double radius) {
    final r = radius * 0.96;
    final rect = Rect.fromCircle(center: center, radius: r);

    // Äußerer Highlight-Rand (oben hell).
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.055
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: pressed ? 0.75 : 0.95),
            const Color(0xFFC5CDDC),
            const Color(0xFF4A5262),
            const Color(0xFF9AA4B6),
          ],
        ).createShader(rect),
    );

    // Innere Nut — dunkler Schattenring.
    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.028
        ..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      center,
      radius * 0.865,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.014
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _drawFiligreeRing(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.016
      ..color = const Color(0xFF3E4656).withValues(alpha: 0.65);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.011
      ..color = const Color(0xFFF7FAFF).withValues(alpha: 0.78);

    for (var i = 0; i < 8; i++) {
      final start = (i * math.pi / 4) + 0.15;
      final sweep = math.pi / 5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.84),
        start,
        sweep,
        false,
        ringPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.80),
        start + 0.08,
        sweep * 0.7,
        false,
        highlight,
      );
    }
  }

  void _drawInnerWell(Canvas canvas, Offset center, double radius) {
    final innerR = radius * 0.60;
    final rect = Rect.fromCircle(center: center, radius: innerR);

    // Vertiefung: harter Schattenrand oben innen.
    canvas.drawCircle(
      center.translate(0, -radius * 0.01),
      innerR * 1.02,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.04),
    );

    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.15,
          colors: [
            pressed ? const Color(0xFF2A3858) : const Color(0xFF455A88),
            const Color(0xFF1A2440),
            const Color(0xFF070B16),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    // Inset-Metallring
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.04
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFF8E98AA),
            Color(0xFF3A4252),
            Color(0xFFDDE4F0),
          ],
        ).createShader(rect),
    );

    // Innere Spiegelung
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * 0.14, -radius * 0.18),
        width: radius * 0.42,
        height: radius * 0.22,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: pressed ? 0.08 : 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.06),
    );
  }

  void _drawGems(Canvas canvas, Offset center, double radius) {
    for (var i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final gemCenter = Offset(
        center.dx + math.cos(angle) * radius * 0.76,
        center.dy + math.sin(angle) * radius * 0.76,
      );
      final gemR = radius * (i.isEven ? 0.078 : 0.058);
      final color = _gemColors[i % _gemColors.length];

      canvas.drawCircle(
        gemCenter.translate(0, gemR * 0.35),
        gemR * 1.1,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, gemR * 0.6),
      );
      canvas.drawCircle(
        gemCenter,
        gemR * 1.7,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, gemR * 0.9),
      );

      final gemRect = Rect.fromCircle(center: gemCenter, radius: gemR);
      canvas.drawCircle(
        gemCenter,
        gemR,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.45),
            radius: 1,
            colors: [
              Color.lerp(color, Colors.white, 0.7)!,
              color,
              Color.lerp(color, const Color(0xFF12081F), 0.55)!,
            ],
          ).createShader(gemRect),
      );
      canvas.drawCircle(
        gemCenter,
        gemR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.012
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              const Color(0xFF8A93A5),
            ],
          ).createShader(gemRect),
      );
      canvas.drawCircle(
        gemCenter.translate(-gemR * 0.28, -gemR * 0.3),
        gemR * 0.24,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
    }
  }

  void _drawCrestCrystal(Canvas canvas, Offset center, double radius) {
    final tip = Offset(center.dx, center.dy - radius * 0.96);
    final crystal = Path()
      ..moveTo(tip.dx, tip.dy - radius * 0.09)
      ..lineTo(tip.dx + radius * 0.06, tip.dy + radius * 0.02)
      ..lineTo(tip.dx, tip.dy + radius * 0.07)
      ..lineTo(tip.dx - radius * 0.06, tip.dy + radius * 0.02)
      ..close();

    canvas.drawPath(
      crystal.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      crystal,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF2FBFF),
            Color(0xFF7EC8FF),
            Color(0xFF3A6BC8),
          ],
        ).createShader(Rect.fromCircle(center: tip, radius: radius * 0.12)),
    );
    canvas.drawPath(
      crystal,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFF8FCFF),
    );
  }

  void _drawPlayTriangle(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx - radius * 0.15, center.dy - radius * 0.26)
      ..quadraticBezierTo(
        center.dx - radius * 0.13,
        center.dy,
        center.dx - radius * 0.15,
        center.dy + radius * 0.26,
      )
      ..lineTo(center.dx + radius * 0.34, center.dy)
      ..close();

    final bounds = path.getBounds();

    // Schatten unter dem Dreieck → hebt es aus dem Well.
    canvas.drawPath(
      path.shift(Offset(radius * 0.02, radius * 0.035)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.04),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pressed
              ? const [
                  Color(0xFFD6DCE8),
                  Color(0xFF9AA5B8),
                  Color(0xFF6A7386),
                ]
              : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFE4EAF4),
                  Color(0xFFA8B2C4),
                  Color(0xFF6E788A),
                ],
        ).createShader(bounds),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.022
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFF5A6476)],
        ).createShader(bounds),
    );

    // Glanzkante auf dem Dreieck
    final shine = Path()
      ..moveTo(center.dx - radius * 0.12, center.dy - radius * 0.18)
      ..lineTo(center.dx + radius * 0.18, center.dy - radius * 0.02)
      ..lineTo(center.dx - radius * 0.12, center.dy - radius * 0.02)
      ..close();
    canvas.drawPath(
      shine,
      Paint()
        ..color = Colors.white.withValues(alpha: pressed ? 0.15 : 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  void _drawTopSpecular(Canvas canvas, Offset center, double radius) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.9),
      -math.pi * 0.95,
      math.pi * 0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.045
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.03),
    );
  }

  @override
  bool shouldRepaint(covariant _FantasyPlayPainter oldDelegate) {
    return oldDelegate.pressed != pressed;
  }
}
