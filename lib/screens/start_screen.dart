import 'package:flutter/material.dart';

import 'gallery_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  static const _backgroundAsset = 'assets/images/background_app.png';
  static const _headlineAsset = 'assets/images/headline_fantasycolor.png';

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onPlay() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const GalleryScreen(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final headlineWidth = size.width * 0.42;
    final headlineMaxHeight = size.height * 0.42;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _backgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: headlineWidth,
                        maxHeight: headlineMaxHeight,
                      ),
                      child: Image.asset(
                        _headlineAsset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    SizedBox(height: size.height * 0.035),
                    SilverPlayButton(onPressed: _onPlay),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SilverPlayButton extends StatelessWidget {
  const SilverPlayButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;

    return Semantics(
      button: true,
      label: 'Play',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7F9FC),
                  Color(0xFFD4D9E4),
                  Color(0xFF9EA7B8),
                  Color(0xFFC8CEDA),
                  Color(0xFFE8ECF3),
                ],
                stops: [0.0, 0.28, 0.55, 0.78, 1.0],
              ),
              border: Border.all(color: const Color(0xFFF2F5FA), width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(-2, -2),
                ),
                BoxShadow(
                  color: const Color(0xFF4A5568).withValues(alpha: 0.55),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFFA8C4FF).withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 38,
                  color: Color(0xFF2A3142),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
