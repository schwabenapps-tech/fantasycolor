import 'package:flutter/material.dart';

/// Art der Farbe / des Mal-Effekts.
enum PaintCategory {
  solid,
  pastel,
  watercolor,
  glow,
  glitter,
}

extension PaintCategoryX on PaintCategory {
  String get label => switch (this) {
        PaintCategory.solid => 'Malfarben',
        PaintCategory.pastel => 'Pastelfarben',
        PaintCategory.watercolor => 'Wasserfarben',
        PaintCategory.glow => 'Glowfarben',
        PaintCategory.glitter => 'Glitzerfarben',
      };

  IconData get icon => switch (this) {
        PaintCategory.solid => Icons.palette_rounded,
        PaintCategory.pastel => Icons.gradient_rounded,
        PaintCategory.watercolor => Icons.water_drop_rounded,
        PaintCategory.glow => Icons.light_mode_rounded,
        PaintCategory.glitter => Icons.auto_awesome_rounded,
      };

  Color get accent => switch (this) {
        PaintCategory.solid => const Color(0xFF5B6FBF),
        PaintCategory.pastel => const Color(0xFFE8A0BF),
        PaintCategory.watercolor => const Color(0xFF5EB7FF),
        PaintCategory.glow => const Color(0xFFFFD56A),
        PaintCategory.glitter => const Color(0xFFC9A6FF),
      };
}

/// Werkzeug in der Farbauswahl.
enum PaintTool {
  /// Fläche antippen und füllen.
  brush,

  /// Frei mit dem Finger zeichnen.
  pen,

  /// Flächen zurücksetzen bzw. Striche wegradieren.
  eraser,
}

extension PaintToolX on PaintTool {
  String get label => switch (this) {
        PaintTool.brush => 'Pinsel',
        PaintTool.pen => 'Stift',
        PaintTool.eraser => 'Radierer',
      };

  IconData get icon => switch (this) {
        PaintTool.brush => Icons.brush_rounded,
        PaintTool.pen => Icons.edit_rounded,
        PaintTool.eraser => Icons.auto_fix_off_rounded,
      };
}

class PaintSwatch {
  const PaintSwatch({
    required this.id,
    required this.color,
    required this.category,
  });

  final String id;
  final Color color;
  final PaintCategory category;
}

/// Feste Fantasy-Paletten je Kategorie.
class PaintCatalog {
  PaintCatalog._();

  static const List<PaintCategory> categories = PaintCategory.values;

  static List<PaintSwatch> swatchesFor(PaintCategory category) {
    final colors = _colors[category]!;
    return [
      for (var i = 0; i < colors.length; i++)
        PaintSwatch(
          id: '${category.name}_$i',
          color: colors[i],
          category: category,
        ),
    ];
  }

  static const Map<PaintCategory, List<Color>> _colors = {
    PaintCategory.solid: [
      Color(0xFFFF4D6D),
      Color(0xFFFF7A45),
      Color(0xFFFFC857),
      Color(0xFFFFF1A8),
      Color(0xFF7DDE92),
      Color(0xFF2EC4B6),
      Color(0xFF4DA3FF),
      Color(0xFF7B6CFF),
      Color(0xFFC56BFF),
      Color(0xFFFF6BCB),
      Color(0xFF8D6E63),
      Color(0xFF243044),
    ],
    PaintCategory.pastel: [
      Color(0xFFFFD6E0),
      Color(0xFFFFE0C2),
      Color(0xFFFFF3C4),
      Color(0xFFD8F5C8),
      Color(0xFFC8F0E8),
      Color(0xFFC9E4FF),
      Color(0xFFD9D2FF),
      Color(0xFFE9CCFF),
      Color(0xFFFFD0F0),
      Color(0xFFE8D5C4),
      Color(0xFFE6EAF2),
      Color(0xFFB8C0D0),
    ],
    PaintCategory.watercolor: [
      Color(0xFFE85A71),
      Color(0xFFF08A5D),
      Color(0xFFF9C74F),
      Color(0xFF90BE6D),
      Color(0xFF43AA8B),
      Color(0xFF4D96FF),
      Color(0xFF6C63FF),
      Color(0xFFB388EB),
      Color(0xFFFF85A1),
      Color(0xFFA67C52),
      Color(0xFF7F8C9A),
      Color(0xFF5C6B7A),
    ],
    PaintCategory.glow: [
      Color(0xFFFF3D81),
      Color(0xFFFF6B35),
      Color(0xFFFFD60A),
      Color(0xFF80FFDB),
      Color(0xFF00F5D4),
      Color(0xFF00BBF9),
      Color(0xFF9B5DE5),
      Color(0xFFF15BB5),
      Color(0xFFFEE440),
      Color(0xFF7BF1A8),
      Color(0xFFA0C4FF),
      Color(0xFFE0AAFF),
    ],
    PaintCategory.glitter: [
      Color(0xFFFF4D6D),
      Color(0xFFFFB703),
      Color(0xFFFFE66D),
      Color(0xFF06D6A0),
      Color(0xFF4CC9F0),
      Color(0xFF7B2CBF),
      Color(0xFFFF85A1),
      Color(0xFFC9A227),
      Color(0xFFE8E8E8),
      Color(0xFFB8F2E6),
      Color(0xFFD0BFFF),
      Color(0xFFFFC6FF),
    ],
  };
}
