class ColoringPage {
  const ColoringPage({
    required this.id,
    required this.title,
    required this.assetPath,
  });

  final String id;
  final String title;
  final String assetPath;

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

  factory ColoringPage.fromAssetPath(String assetPath) {
    final file = assetPath.split('/').last;
    final id = file.replaceAll(RegExp(r'\.svg$', caseSensitive: false), '');
    return ColoringPage(
      id: id,
      title: titleFromPath(assetPath),
      assetPath: assetPath,
    );
  }
}
