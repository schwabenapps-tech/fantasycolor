import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/coloring_page.dart';

class AssetDimensionsManifest {
  AssetDimensionsManifest._(this._entries);

  final Map<String, ({double width, double height})> _entries;

  static AssetDimensionsManifest? _cache;

  static Future<AssetDimensionsManifest> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/asset_dimensions.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final entries = <String, ({double width, double height})>{};

    for (final section in json.values) {
      for (final item in section as List<dynamic>) {
        final map = item as Map<String, dynamic>;
        entries[map['path'] as String] = (
          width: (map['width'] as num).toDouble(),
          height: (map['height'] as num).toDouble(),
        );
      }
    }

    _cache = AssetDimensionsManifest._(entries);
    return _cache!;
  }

  ({double width, double height}) sizeFor(String assetPath) {
    return _entries[assetPath] ?? (width: 1, height: 1);
  }

  ColoringPage pageFromPath(String assetPath) {
    final size = sizeFor(assetPath);
    return ColoringPage.fromAssetPath(
      assetPath,
      width: size.width,
      height: size.height,
    );
  }
}
