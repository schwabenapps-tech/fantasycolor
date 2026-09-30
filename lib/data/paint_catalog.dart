import 'package:flutter/material.dart';

/// Art der Farbe / des Mal-Effekts.
enum PaintCategory {
  solid,
  pastel,
}

extension PaintCategoryX on PaintCategory {
  String get label => switch (this) {
        PaintCategory.solid => 'Paint colors',
        PaintCategory.pastel => 'Pastel colors',
      };

  IconData get icon => switch (this) {
        PaintCategory.solid => Icons.palette_rounded,
        PaintCategory.pastel => Icons.gradient_rounded,
      };

  Color get accent => switch (this) {
        PaintCategory.solid => const Color(0xFF5B6FBF),
        PaintCategory.pastel => const Color(0xFFE8A0BF),
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
        PaintTool.brush => 'Brush',
        PaintTool.pen => 'Pen',
        PaintTool.eraser => 'Eraser',
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
    this.number,
  });

  final String id;
  final Color color;
  final PaintCategory category;

  /// Nur bei Pixel-/Malen-nach-Zahlen: Nummer auf dem Feld (1…n).
  final int? number;

  bool get isNumbered => number != null;
}

/// Filter im Malbereich: klassisch vs. Pixel nach Zahlen.
enum MalenFilter {
  einfach,
  fortgeschritten;

  String get label => switch (this) {
        MalenFilter.einfach => 'Simple',
        MalenFilter.fortgeschritten => 'Pixel Art',
      };

  String get hint => switch (this) {
        MalenFilter.einfach => 'Color with brush & pen',
        MalenFilter.fortgeschritten => 'Pixel · paint by numbers',
      };

  IconData get icon => switch (this) {
        MalenFilter.einfach => Icons.brush_rounded,
        MalenFilter.fortgeschritten => Icons.grid_on_rounded,
      };
}

/// Feste Fantasy-Paletten je Kategorie + dynamische Bild-Paletten.
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

  /// Flache Palette für die untere Leiste: Paint colors + Pastell, ohne Filter.
  static List<PaintSwatch> get allSwatches => [
        for (final category in categories) ...swatchesFor(category),
      ];

  /// Nummerierte Swatches aus den echten Farben eines Pixelbilds.
  ///
  /// Erscheinen in der Leiste wie normale Paint colors — aber nur die
  /// Farben, die für genau dieses Bild vorgesehen sind.
  static List<PaintSwatch> numberedFromImageColors(List<Color> colors) {
    return [
      for (var i = 0; i < colors.length; i++)
        PaintSwatch(
          id: 'pixel_img_${i + 1}',
          color: colors[i],
          category: PaintCategory.solid,
          number: i + 1,
        ),
    ];
  }

  static const Map<PaintCategory, List<Color>> _colors = {
    PaintCategory.solid: [
      // Rot / Beere
      Color(0xFFFF2D55),
      Color(0xFFFF4D6D),
      Color(0xFFE63946),
      Color(0xFFDC2F02),
      Color(0xFFC9184A),
      Color(0xFF9B2226),
      Color(0xFF6A040F),
      Color(0xFFB5179E),
      // Orange / Koralle
      Color(0xFFFF6B35),
      Color(0xFFFF7A45),
      Color(0xFFFF8C42),
      Color(0xFFFF9F1C),
      Color(0xFFF4A261),
      Color(0xFFE76F51),
      // Gelb / Gold
      Color(0xFFFFC857),
      Color(0xFFFFD60A),
      Color(0xFFFFE66D),
      Color(0xFFFFF1A8),
      Color(0xFFE9C46A),
      Color(0xFFC9A227),
      // Grün
      Color(0xFFD8F3DC),
      Color(0xFFB7E4C7),
      Color(0xFF95D5B2),
      Color(0xFF7DDE92),
      Color(0xFF52B788),
      Color(0xFF2DC653),
      Color(0xFF40916C),
      Color(0xFF208B3A),
      Color(0xFF1B4332),
      Color(0xFF081C15),
      // Mint / Türkis
      Color(0xFF80FFDB),
      Color(0xFF2EC4B6),
      Color(0xFF00F5D4),
      Color(0xFF06D6A0),
      Color(0xFF0EAD69),
      Color(0xFF0077B6),
      // Blau
      Color(0xFF90E0EF),
      Color(0xFF4CC9F0),
      Color(0xFF00BBF9),
      Color(0xFF4DA3FF),
      Color(0xFF3A86FF),
      Color(0xFF4361EE),
      Color(0xFF1D4ED8),
      Color(0xFF3D5A80),
      Color(0xFF1E3A5F),
      Color(0xFF0D1B2A),
      // Lila / Pink
      Color(0xFFC77DFF),
      Color(0xFF7B6CFF),
      Color(0xFF9B5DE5),
      Color(0xFF7B2CBF),
      Color(0xFF5A189A),
      Color(0xFFC56BFF),
      Color(0xFFF15BB5),
      Color(0xFFFF6BCB),
      Color(0xFFFF85A1),
      Color(0xFFFF99C8),
      // Hauttöne
      Color(0xFFFFF0E6),
      Color(0xFFFFDBAC),
      Color(0xFFF1C27D),
      Color(0xFFE0AC69),
      Color(0xFFC68642),
      Color(0xFF8D5524),
      Color(0xFF6F4518),
      Color(0xFF5D4037),
      Color(0xFF3E2723),
      // Braun / Erde
      Color(0xFFD4A373),
      Color(0xFFBC6C25),
      Color(0xFF8D6E63),
      Color(0xFF6D4C41),
      Color(0xFF4E342E),
      // Neutral
      Color(0xFFFFFFFF),
      Color(0xFFF8F9FA),
      Color(0xFFE6EAF2),
      Color(0xFFCED4DA),
      Color(0xFF9AA3B2),
      Color(0xFF6C757D),
      Color(0xFF4A5568),
      Color(0xFF343A40),
      Color(0xFF1A1A2E),
      Color(0xFF000000),
    ],
    PaintCategory.pastel: [
      // Rosa / Pfirsich
      Color(0xFFFFF5F7),
      Color(0xFFFFE5EC),
      Color(0xFFFFD6E0),
      Color(0xFFFFC2D1),
      Color(0xFFFFB3C6),
      Color(0xFFFFE0C2),
      Color(0xFFFFE8D6),
      Color(0xFFFFDAB9),
      Color(0xFFFFCCBC),
      // Gelb / Creme / Apricot
      Color(0xFFFFFCF2),
      Color(0xFFFFF8E7),
      Color(0xFFFFF3C4),
      Color(0xFFFFEAA7),
      Color(0xFFFCEFB4),
      Color(0xFFFFE082),
      Color(0xFFFFECB3),
      Color(0xFFFFE0B2),
      // Grün / Mint
      Color(0xFFF1FAEE),
      Color(0xFFE8F8E8),
      Color(0xFFD8F5C8),
      Color(0xFFC8E6C9),
      Color(0xFFA8E6CF),
      Color(0xFFB2DFDB),
      Color(0xFFDCEDC8),
      Color(0xFFC5E1A5),
      Color(0xFFE0F2F1),
      // Türkis / Blau
      Color(0xFFE0F7FA),
      Color(0xFFC8F0E8),
      Color(0xFFB2EBF2),
      Color(0xFFC9E4FF),
      Color(0xFFBBDEFB),
      Color(0xFFAEDFF7),
      Color(0xFF90CAF9),
      Color(0xFFB3E5FC),
      Color(0xFFD6EAF8),
      Color(0xFFE3F2FD),
      // Lila / Lavendel / Pink
      Color(0xFFF8F0FC),
      Color(0xFFEDE7F6),
      Color(0xFFE1BEE7),
      Color(0xFFD9D2FF),
      Color(0xFFD1C4E9),
      Color(0xFFE9CCFF),
      Color(0xFFF3E5F5),
      Color(0xFFF8BBD0),
      Color(0xFFFFD0F0),
      Color(0xFFFCE4EC),
      Color(0xFFF3D9FA),
      // Haut / Beige / Sand
      Color(0xFFFFF8F0),
      Color(0xFFFFF0E6),
      Color(0xFFFAE1DD),
      Color(0xFFE8D5C4),
      Color(0xFFE6CCB2),
      Color(0xFFD7CCC8),
      Color(0xFFCDB4A0),
      Color(0xFFB08968),
      Color(0xFFDDB892),
      // Grau / Weiß / Silbrig
      Color(0xFFFFFFFF),
      Color(0xFFFAFBFC),
      Color(0xFFF1F3F5),
      Color(0xFFE6EAF2),
      Color(0xFFDEE2E6),
      Color(0xFFD1D5DB),
      Color(0xFFB8C0D0),
      Color(0xFFADB5BD),
      Color(0xFF9CA3AF),
      Color(0xFF868E96),
    ],
  };
}
