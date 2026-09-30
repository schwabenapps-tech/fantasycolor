import 'package:flutter/material.dart';

/// Silberner Back-Button im Fantasy-Stil (wiederverwendbar).
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
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
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
                Color(0xFFFFF6E8),
                Color(0xFFE8C9A0),
                Color(0xFFC9A06A),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC9A06A).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: const Color(0xFF3A2810),
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
