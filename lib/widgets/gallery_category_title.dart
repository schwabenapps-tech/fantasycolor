import 'package:flutter/material.dart';

/// Kategorie-Titel oben in Galerie-Ansichten — mittig wie im Event-Hub (Halloween).
class GalleryCategoryTitle extends StatelessWidget {
  const GalleryCategoryTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.accentColor = const Color(0xFFFFE7A0),
  });

  final String title;
  final String? subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accentColor,
              fontSize: isTablet ? 32 : 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              shadows: const [
                Shadow(
                  color: Color(0xAA000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: isTablet ? 15 : 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                shadows: const [
                  Shadow(
                    color: Color(0x88000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
