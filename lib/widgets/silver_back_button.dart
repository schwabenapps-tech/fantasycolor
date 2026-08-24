import 'package:flutter/material.dart';

/// Silberner Zurück-Button im Fantasy-Stil (wiederverwendbar).
class SilverBackButton extends StatelessWidget {
  const SilverBackButton({
    super.key,
    required this.onPressed,
    this.size = 42,
    this.iconSize = 22,
    this.icon = Icons.arrow_back_rounded,
  });

  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
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
          child: Icon(
            icon,
            color: const Color(0xFF243044),
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
