import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../widgets/coloring_page_image.dart';

/// Vollbild-Ansicht eines Ausmalbilds in echter Seitenproportion.
class ColoringPreviewScreen extends StatelessWidget {
  const ColoringPreviewScreen({super.key, required this.page});

  final ColoringPage page;

  static const _paperBackground = 'assets/images/ausmalhintergund.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _paperBackground,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                    child: ColoringPageSheet(
                      page: page,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 12,
                  child: _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF7F9FC),
                Color(0xFFC5CCD8),
                Color(0xFF9AA3B5),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF243044), size: 24),
        ),
      ),
    );
  }
}
