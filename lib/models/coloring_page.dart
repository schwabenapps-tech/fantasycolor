class ColoringPage {
  const ColoringPage({
    required this.id,
    required this.title,
    required this.assetPath,
    this.width = 1,
    this.height = 1,
  });

  final String id;
  final String title;
  final String assetPath;

  /// Originale SVG-Breite in Pixeln (aus dem Dateikopf).
  final double width;

  /// Originale SVG-Höhe in Pixeln (aus dem Dateikopf).
  final double height;

  /// Seitenverhältnis Breite/Höhe — für weißen Hintergrund im Bildformat.
  double get aspectRatio {
    if (width <= 0 || height <= 0) return 1;
    return width / height;
  }

  /// Titel aus Dateiname, z. B. `ballerina_1.svg` → `Ballerina 1`.
  static String titleFromPath(String assetPath) {
    final file = assetPath.split('/').last;
    final stem = file.replaceAll(RegExp(r'\.svg$', caseSensitive: false), '');
    return stem
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll('+', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }

  factory ColoringPage.fromAssetPath(
    String assetPath, {
    double width = 1,
    double height = 1,
  }) {
    final file = assetPath.split('/').last;
    final id = file.replaceAll(RegExp(r'\.svg$', caseSensitive: false), '');
    return ColoringPage(
      id: id,
      title: titleFromPath(assetPath),
      assetPath: assetPath,
      width: width,
      height: height,
    );
  }
}
