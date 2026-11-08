import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/event_catalog.dart';
import '../data/sticker_catalog.dart';
import '../models/coloring_page.dart';
import '../utils/image_source.dart';

/// Lädt Pack-Manifest + Dateien von Cloudflare R2.
class RemotePackService extends ChangeNotifier {
  RemotePackService._();

  static final RemotePackService instance = RemotePackService._();

  static const cdnBase = 'https://cdn.schwabenapps.com';
  static const _prefsManifestVersion = 'remote_packs_manifest_version';
  static const _prefsPackVersions = 'remote_packs_versions_json';
  static const _prefsNewSince = 'remote_packs_new_since_json';

  /// Wie [EventTags.newBadgeDuration] — hier lokal, um Zyklen zu vermeiden.
  static const newBadgeDuration = Duration(days: 14);

  bool _syncing = false;
  bool get isSyncing => _syncing;

  int _generation = 0;
  int get generation => _generation;

  List<RemotePack> _packs = const [];
  List<RemotePack> get packs => List.unmodifiable(_packs);

  /// Remote-Seiten-ID → Datum, ab dem sie als „neu“ gelten.
  Map<String, DateTime> _newSince = {};

  bool _indexLoaded = false;

  Future<void> sync() async {
    if (_syncing) return;
    _syncing = true;
    notifyListeners();
    try {
      await _ensureIndexLoaded();
      final remote = await _fetchManifest();
      if (remote == null) return;

      final prefs = await SharedPreferences.getInstance();
      final packVersions = _readPackVersions(prefs);
      _newSince = _readNewSince(prefs);
      final root = await _packsRoot();
      var changed = false;
      final beforeSignature = _packsSignature(_packs);

      for (final pack in remote.packs) {
        final localVersion = packVersions[pack.id] ?? 0;
        if (localVersion >= pack.version && await _packComplete(root, pack)) {
          // Auch ohne Download: released_at / bekannte Seiten als neu merken.
          _rememberNewPages(pack);
          continue;
        }
        // Neue Pack-Version: alte Dateien entfernen, sonst bleiben stale PNGs.
        if (localVersion > 0 && localVersion < pack.version) {
          final dir = Directory('${root.path}/${pack.id}');
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        }
        await _downloadPack(root, pack);
        _rememberNewPages(pack, forceFresh: localVersion < pack.version);
        // Version erst merken, wenn alle Dateien da sind — sonst bleibt der
        // Sync bei Resume hängen und Stickers fehlen still.
        if (await _packComplete(root, pack)) {
          packVersions[pack.id] = pack.version;
        } else {
          debugPrint(
            'RemotePackService: pack ${pack.id} incomplete — retry next sync',
          );
        }
        changed = true;
      }

      final remoteIds = {for (final p in remote.packs) p.id};
      for (final id in packVersions.keys.toList()) {
        if (!remoteIds.contains(id)) {
          packVersions.remove(id);
          final dir = Directory('${root.path}/$id');
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
          changed = true;
        }
      }

      await prefs.setInt(_prefsManifestVersion, remote.version);
      await prefs.setString(_prefsPackVersions, jsonEncode(packVersions));
      await prefs.setString(
        _prefsNewSince,
        jsonEncode({
          for (final e in _newSince.entries)
            e.key: e.value.toIso8601String().split('T').first,
        }),
      );
      await _cacheManifest(remote);

      _packs = remote.packs;
      _indexLoaded = true;
      final afterSignature = _packsSignature(_packs);
      if (changed || beforeSignature != afterSignature) {
        _generation++;
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('RemotePackService.sync failed: $e\n$st');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Home/Galerie: Remote-Motiv innerhalb von [newBadgeDuration] als neu.
  bool isNewPage(String pageId, {DateTime? now}) {
    final stored = _newSince[pageId];
    if (_isWithinNewBadge(stored, now: now)) return true;

    for (final pack in _packs) {
      final released = pack.releasedAt;
      if (!_isWithinNewBadge(released, now: now)) continue;
      for (final relative in pack.files) {
        if (!_isTrackedRemoteFile(relative)) continue;
        if (_matchesRemotePageId(pack.id, relative, pageId)) return true;
      }
    }
    return false;
  }

  /// raw Stem-ID, normalisierte Stem-ID oder nackter normalize-Key.
  static bool _matchesRemotePageId(
    String packId,
    String relative,
    String pageId,
  ) {
    if (remotePageId(packId, relative) == pageId) return true;
    final stem = normalizeImageKey(relative.split('/').last);
    if (stem.isEmpty) return false;
    return pageId == stem || pageId == 'remote_${packId}_$stem';
  }

  void _rememberNewPages(RemotePack pack, {bool forceFresh = false}) {
    final released = pack.releasedAt ?? DateTime.now();
    final day = DateTime(released.year, released.month, released.day);
    for (final relative in pack.files) {
      if (!_isTrackedRemoteFile(relative)) continue;
      final rawId = remotePageId(pack.id, relative);
      // Auch Bundle-Stem (fee_clean_50), falls Remote wegen Dedup verworfen wird.
      final stem = normalizeImageKey(relative.split('/').last);
      // Sticker-Katalog-IDs: remote_{pack}_{normalizeImageKey} (Upload-Script).
      final normalizedId =
          stem.isEmpty ? null : 'remote_${pack.id}_$stem';
      for (final key in {
        rawId,
        if (stem.isNotEmpty) stem,
        ?normalizedId,
      }) {
        if (forceFresh) {
          _newSince[key] = day;
        } else {
          _newSince.putIfAbsent(key, () => day);
        }
      }
    }
  }

  /// Coloring/Puzzle/Stickers (ohne catalog.json).
  static bool _isTrackedRemoteFile(String relative) {
    if (relative.endsWith('/catalog.json') || relative.endsWith('catalog.json')) {
      return false;
    }
    return relative.contains('/coloring/') ||
        relative.contains('/puzzle/') ||
        relative.contains('/stickers/');
  }

  /// Alias für Stickers — gleiche New-Badge-Fenster wie Galerie.
  bool isNewSticker(String stickerId, {DateTime? now}) =>
      isNewPage(stickerId, now: now);

  DateTime? stickerAddedAt(String stickerId) => pageAddedAt(stickerId);

  /// Datum für Sortierung „neueste zuerst“ (Prefs + Pack `released_at`).
  DateTime? pageAddedAt(String pageId) {
    final stored = _newSince[pageId];
    if (stored != null) return stored;
    DateTime? best;
    for (final pack in _packs) {
      final released = pack.releasedAt;
      if (released == null) continue;
      for (final relative in pack.files) {
        if (!_isTrackedRemoteFile(relative)) continue;
        if (!_matchesRemotePageId(pack.id, relative, pageId)) continue;
        if (best == null || released.isAfter(best)) {
          best = DateTime(released.year, released.month, released.day);
        }
      }
    }
    return best;
  }

  /// CDN-URL mit korrektem Path-Encoding (Kommas, Spaces, Unicode).
  static Uri cdnUriFor(String relative) {
    final base = Uri.parse(cdnBase);
    final segments = <String>[
      ...base.pathSegments.where((s) => s.isNotEmpty),
      ...relative.split('/').where((s) => s.isNotEmpty),
    ];
    return base.replace(pathSegments: segments);
  }

  static bool _isWithinNewBadge(DateTime? since, {DateTime? now}) {
    if (since == null) return false;
    final n = now ?? DateTime.now();
    final age = n.difference(since);
    return !age.isNegative && age <= newBadgeDuration;
  }

  static String _packsSignature(List<RemotePack> packs) {
    return [
      for (final p in packs)
        '${p.id}:${p.version}:${p.files.length}:${p.startsAt}:${p.endsAt}:${p.releasedAt}',
    ].join('|');
  }

  Future<List<ColoringPage>> coloringPages({
    required Set<String> bundleSourceKeys,
  }) {
    return _pagesForSection(
      section: 'coloring',
      bundleSourceKeys: bundleSourceKeys,
    );
  }

  Future<List<ColoringPage>> puzzlePages({
    required Set<String> bundleSourceKeys,
  }) {
    return _pagesForSection(
      section: 'puzzle',
      bundleSourceKeys: bundleSourceKeys,
    );
  }

  /// Stickers aus gecachten Packs (`packs/{id}/stickers/` + optional `catalog.json`).
  Future<List<StickerEntry>> remoteStickerEntries() async {
    await _ensureIndexLoaded();
    final root = await _packsRoot();
    final out = <StickerEntry>[];
    final seenIds = <String>{};
    // Neueste Packs zuerst — neue Stickers landen vorne im Album.
    final packsNewestFirst = _packs.reversed.toList(growable: false);
    for (final pack in packsNewestFirst) {
      final stickerDir = Directory('${root.path}/${pack.id}/stickers');
      if (!await stickerDir.exists()) continue;

      var loadedFromCatalog = 0;
      final catalogFile = File('${stickerDir.path}/catalog.json');
      if (await catalogFile.exists()) {
        try {
          final json = jsonDecode(await catalogFile.readAsString());
          if (json is Map<String, dynamic>) {
            final list = json['stickers'];
            if (list is List) {
              for (final item in list) {
                if (item is! Map) continue;
                final map = Map<String, dynamic>.from(item);
                final id = map['id']?.toString();
                final assetName = map['asset']?.toString();
                if (id == null || id.isEmpty || assetName == null) continue;
                final fileName = assetName.split('/').last;
                final file = await _resolveStickerFile(stickerDir, fileName);
                if (file == null) continue;
                if (!seenIds.add(id)) continue;
                out.add(
                  StickerEntry(
                    id: id,
                    assetPath: file.path,
                    coloringId: map['coloringId'] as String?,
                    puzzleId: map['puzzleId'] as String?,
                  ),
                );
                loadedFromCatalog++;
              }
            }
          }
        } catch (e) {
          debugPrint('RemotePackService: sticker catalog ${pack.id}: $e');
        }
      }

      // Fallback wenn kein Katalog oder Katalog 0 Treffer (Name-Mismatch).
      if (loadedFromCatalog > 0) continue;

      final images = stickerDir
          .listSync()
          .whereType<File>()
          .where((f) {
            final n = f.path.toLowerCase();
            return n.endsWith('.png') ||
                n.endsWith('.jpg') ||
                n.endsWith('.jpeg') ||
                n.endsWith('.webp');
          })
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final file in images) {
        final name = file.uri.pathSegments.last;
        final id = 'remote_${pack.id}_${normalizeImageKey(name)}';
        if (!seenIds.add(id)) continue;
        out.add(StickerEntry(id: id, assetPath: file.path));
      }
    }
    return out;
  }

  /// Direkter Dateiname, Space→`_`, oder normalizeImageKey-Match.
  Future<File?> _resolveStickerFile(Directory stickerDir, String fileName) async {
    final candidates = <String>{
      fileName,
      fileName.replaceAll(' ', '_'),
      fileName.replaceAll(' ', '-'),
    };
    for (final name in candidates) {
      final file = File('${stickerDir.path}/$name');
      if (await file.exists()) return file;
    }
    final want = normalizeImageKey(fileName);
    if (want.isEmpty) return null;
    try {
      for (final entity in stickerDir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final lower = name.toLowerCase();
        if (!(lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.webp'))) {
          continue;
        }
        if (normalizeImageKey(name) == want) return entity;
      }
    } catch (_) {}
    return null;
  }

  List<ContentEvent> remoteEvents() {
    return [
      for (final pack in _packs)
        if (pack.startsAt != null || pack.endsAt != null)
          ContentEvent(
            id: pack.id,
            title: pack.title,
            startsAt: pack.startsAt,
            endsAt: pack.endsAt,
            coloringIds: {
              for (final f in pack.files)
                if (f.contains('/coloring/')) remotePageId(pack.id, f),
            },
            puzzleIds: {
              for (final f in pack.files)
                if (f.contains('/puzzle/')) remotePageId(pack.id, f),
            },
          ),
    ];
  }

  static String remotePageId(String packId, String relative) {
    final stem = relative.split('/').last.replaceAll(
          RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false),
          '',
        );
    return 'remote_${packId}_$stem';
  }

  Future<List<ColoringPage>> _pagesForSection({
    required String section,
    required Set<String> bundleSourceKeys,
  }) async {
    await _ensureIndexLoaded();
    final root = await _packsRoot();
    final out = <ColoringPage>[];
    for (final pack in _packs) {
      for (final relative in pack.files) {
        if (!relative.contains('/$section/')) continue;
        final fileName = relative.split('/').last;
        final key = normalizeImageKey(fileName);
        if (bundleSourceKeys.contains(key)) {
          debugPrint(
            'RemotePackService: skip $relative (already in bundle as $key)',
          );
          continue;
        }
        final file = File('${root.path}/${pack.id}/$section/$fileName');
        if (!await file.exists()) continue;
        final size = await _pngSize(file);
        out.add(
          ColoringPage(
            id: remotePageId(pack.id, relative),
            title: ColoringPage.titleFromPath(file.path),
            assetPath: file.path,
            width: size.$1,
            height: size.$2,
          ),
        );
      }
    }
    return out;
  }

  Future<void> _ensureIndexLoaded() async {
    if (_indexLoaded) return;
    final cached = await _readCachedManifest();
    if (cached != null) {
      _packs = cached.packs;
    }
    final prefs = await SharedPreferences.getInstance();
    _newSince = _readNewSince(prefs);
    _indexLoaded = true;
  }

  Future<Directory> _packsRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/packs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _manifestCacheFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/remote_manifest.json');
  }

  Future<void> _cacheManifest(_RemoteManifest manifest) async {
    final file = await _manifestCacheFile();
    await file.writeAsString(
      jsonEncode({
        'version': manifest.version,
        'packs': [
          for (final p in manifest.packs)
            {
              'id': p.id,
              'version': p.version,
              'title': p.title,
              'files': p.files,
              if (p.startsAt != null)
                'starts_at': p.startsAt!.toIso8601String().split('T').first,
              if (p.endsAt != null)
                'ends_at': p.endsAt!.toIso8601String().split('T').first,
              if (p.releasedAt != null)
                'released_at':
                    p.releasedAt!.toIso8601String().split('T').first,
            },
        ],
      }),
    );
  }

  Future<_RemoteManifest?> _readCachedManifest() async {
    try {
      final file = await _manifestCacheFile();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return _RemoteManifest.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<_RemoteManifest?> _fetchManifest() async {
    final uri = Uri.parse('$cdnBase/manifest.json');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      debugPrint('RemotePackService: manifest HTTP ${response.statusCode}');
      return null;
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;
    return _RemoteManifest.fromJson(json);
  }

  Future<void> _downloadPack(Directory root, RemotePack pack) async {
    for (final relative in pack.files) {
      final parts = relative.split('/');
      if (parts.length < 4) continue;
      final section = parts[2];
      final fileName = parts.last;
      final dest = File('${root.path}/${pack.id}/$section/$fileName');
      if (await dest.exists()) continue;
      await dest.parent.create(recursive: true);
      final uri = cdnUriFor(relative);
      final response =
          await http.get(uri).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        debugPrint(
          'RemotePackService: fail $relative (${response.statusCode})',
        );
        continue;
      }
      await dest.writeAsBytes(response.bodyBytes, flush: true);
    }
  }

  Future<bool> _packComplete(Directory root, RemotePack pack) async {
    for (final relative in pack.files) {
      final parts = relative.split('/');
      if (parts.length < 4) continue;
      final file = File('${root.path}/${pack.id}/${parts[2]}/${parts.last}');
      if (!await file.exists()) return false;
    }
    return true;
  }

  Map<String, int> _readPackVersions(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsPackVersions);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      return {
        for (final e in json.entries)
          e.key.toString(): int.tryParse(e.value.toString()) ?? 0,
      };
    } catch (_) {
      return {};
    }
  }

  Map<String, DateTime> _readNewSince(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsNewSince);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      final out = <String, DateTime>{};
      for (final e in json.entries) {
        final parsed = ContentEvent.parseDate(e.value.toString());
        if (parsed != null) out[e.key.toString()] = parsed;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<(double, double)> _pngSize(File file) async {
    try {
      final bytes = await loadImageBytes(file.path);
      // Prefer image package via decode — avoid ui import issues on tests.
      // PNG IHDR: width/height at bytes 16..23 big-endian.
      if (bytes.length >= 24 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        final w = (bytes[16] << 24) |
            (bytes[17] << 16) |
            (bytes[18] << 8) |
            bytes[19];
        final h = (bytes[20] << 24) |
            (bytes[21] << 16) |
            (bytes[22] << 8) |
            bytes[23];
        if (w > 0 && h > 0) return (w.toDouble(), h.toDouble());
      }
    } catch (_) {}
    return (1.0, 1.0);
  }
}

class RemotePack {
  const RemotePack({
    required this.id,
    required this.version,
    required this.title,
    required this.files,
    this.startsAt,
    this.endsAt,
    this.releasedAt,
  });

  final String id;
  final int version;
  final String title;
  final List<String> files;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Ab diesem Datum gelten Pack-Motive als „neu“ (Home / Badges).
  final DateTime? releasedAt;

  factory RemotePack.fromJson(Map<String, dynamic> json) {
    final files = <String>[];
    final rawFiles = json['files'];
    if (rawFiles is List) {
      for (final f in rawFiles) {
        files.add(f.toString());
      }
    }
    return RemotePack(
      id: json['id']?.toString() ?? '',
      version: int.tryParse(json['version']?.toString() ?? '') ?? 1,
      title: json['title']?.toString() ?? 'Pack',
      files: files,
      startsAt: ContentEvent.parseDate(json['starts_at']),
      endsAt: ContentEvent.parseDate(json['ends_at']),
      releasedAt: ContentEvent.parseDate(json['released_at']),
    );
  }
}

class _RemoteManifest {
  const _RemoteManifest({required this.version, required this.packs});

  final int version;
  final List<RemotePack> packs;

  factory _RemoteManifest.fromJson(Map<String, dynamic> json) {
    final packs = <RemotePack>[];
    final raw = json['packs'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          packs.add(RemotePack.fromJson(item));
        } else if (item is Map) {
          packs.add(RemotePack.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return _RemoteManifest(
      version: int.tryParse(json['version']?.toString() ?? '') ?? 1,
      packs: packs,
    );
  }
}
