import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/sticker_catalog.dart';
import '../providers/sticker_collection_store.dart';
import '../services/analytics_service.dart';

/// Magisches Grid-Album über dem Hub (Hub bleibt gedimmt sichtbar).
class StickerAlbumOverlay extends StatefulWidget {
  const StickerAlbumOverlay({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  State<StickerAlbumOverlay> createState() => _StickerAlbumOverlayState();
}

class _StickerAlbumOverlayState extends State<StickerAlbumOverlay> {
  bool _showRules = false;
  int _page = 0;
  StickerEntry? _preview;
  bool _previewOwned = false;
  final _pageController = PageController();

  static const _perPage = 9;
  static const _cols = 3;
  static const _rows = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<StickerCollectionStore>();
      if (!store.isReady) {
        unawaited(store.load());
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _exportPack(StickerCollectionStore store) async {
    final cat = store.catalog;
    if (cat == null || !store.isComplete) return;
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/fairy_stickers');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await dir.create(recursive: true);
      final files = <XFile>[];
      for (final s in cat.stickers) {
        final data = await rootBundle.load(s.assetPath);
        final name = s.assetPath.split('/').last;
        final out = File('${dir.path}/$name');
        await out.writeAsBytes(data.buffer.asUint8List());
        files.add(XFile(out.path));
      }
      AnalyticsService.instance.logStickerPackExport(files.length);
      await SharePlus.instance.share(
        ShareParams(
          files: files,
          text: 'Fairy Fantasy Color stickers',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share stickers: $e')),
      );
    }
  }

  void _openPreview(StickerEntry sticker, bool owned) {
    setState(() {
      _preview = sticker;
      _previewOwned = owned;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StickerCollectionStore>();
    final cat = store.catalog;
    final stickers = cat?.stickers ?? const <StickerEntry>[];
    final pageCount = stickers.isEmpty
        ? 1
        : ((stickers.length + _perPage - 1) / _perPage).ceil();
    if (_page >= pageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _page = pageCount - 1);
      });
    }
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _showRules ? 0.28 : 1,
            child: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      landscape ? 20 : 16,
                      landscape ? 8 : 12,
                      landscape ? 20 : 16,
                      landscape ? 6 : 10,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${store.ownedCount} / ${store.totalCount}',
                          style: TextStyle(
                            color: const Color(0xFFFFE7A0),
                            fontWeight: FontWeight.w800,
                            fontSize: landscape ? 17 : 20,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final gap = landscape ? 8.0 : 10.0;
                              final inset = landscape ? 12.0 : 14.0;
                              // Leave a little slack so the panel never clips.
                              final maxW = constraints.maxWidth;
                              final maxH = constraints.maxHeight;
                              final innerMaxW = (maxW - inset * 2)
                                  .clamp(0.0, double.infinity);
                              final innerMaxH = (maxH - inset * 2)
                                  .clamp(0.0, double.infinity);
                              final cellFromW =
                                  (innerMaxW - gap * (_cols - 1)) / _cols;
                              final cellFromH =
                                  (innerMaxH - gap * (_rows - 1)) / _rows;
                              final cell =
                                  (cellFromW < cellFromH ? cellFromW : cellFromH)
                                      .clamp(48.0, landscape ? 120.0 : 140.0);
                              final gridW =
                                  cell * _cols + gap * (_cols - 1);
                              final gridH =
                                  cell * _rows + gap * (_rows - 1);
                              final panelW = gridW + inset * 2;
                              final panelH = gridH + inset * 2;

                              return Center(
                                child: SizedBox(
                                  width: panelW,
                                  height: panelH,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: const Color(0xCC1A2438),
                                      borderRadius:
                                          BorderRadius.circular(22),
                                      border: Border.all(
                                        color: const Color(0xFFFFE7A0)
                                            .withValues(alpha: 0.35),
                                        width: 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x66000000),
                                          blurRadius: 28,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(22),
                                      child: PageView.builder(
                                        controller: _pageController,
                                        itemCount: pageCount,
                                        onPageChanged: (i) {
                                          HapticFeedback.selectionClick();
                                          setState(() => _page = i);
                                        },
                                        itemBuilder: (context, page) {
                                          final start = page * _perPage;
                                          final slice = stickers
                                              .skip(start)
                                              .take(_perPage)
                                              .toList();
                                          return Padding(
                                            padding:
                                                EdgeInsets.all(inset),
                                            child: GridView.builder(
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              gridDelegate:
                                                  SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: _cols,
                                                mainAxisSpacing: gap,
                                                crossAxisSpacing: gap,
                                                childAspectRatio: 1,
                                              ),
                                              itemCount: slice.length,
                                              itemBuilder:
                                                  (context, i) {
                                                final s = slice[i];
                                                final owned =
                                                    store.owns(s.id);
                                                return _AlbumStickerCell(
                                                  sticker: s,
                                                  owned: owned,
                                                  onTap: () =>
                                                      _openPreview(
                                                    s,
                                                    owned,
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (pageCount > 1) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_page + 1} / $pageCount',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (store.isComplete)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton.icon(
                              onPressed: () => _exportPack(store),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Sticker pack'),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFFFE8A8),
                                foregroundColor: const Color(0xFF4A3208),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 12,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: widget.onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 12,
                    child: IconButton(
                      tooltip: 'Rules',
                      onPressed: () => setState(() => _showRules = true),
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFFFE7A0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showRules)
            _RulesPanel(onClose: () => setState(() => _showRules = false)),
          if (_preview != null)
            _StickerPreviewOverlay(
              sticker: _preview!,
              owned: _previewOwned,
              onClose: () => setState(() => _preview = null),
            ),
        ],
      ),
    );
  }
}

class _AlbumStickerCell extends StatelessWidget {
  const _AlbumStickerCell({
    required this.sticker,
    required this.owned,
    required this.onTap,
  });

  final StickerEntry sticker;
  final bool owned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      sticker.assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    final body = owned
        ? image
        : ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.05, 0.05, 0.05, 0, 18,
              0.05, 0.05, 0.05, 0, 18,
              0.08, 0.08, 0.1, 0, 28,
              0, 0, 0, 0.55, 0,
            ]),
            child: image,
          );
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: body,
        ),
      ),
    );
  }
}

class _StickerPreviewOverlay extends StatelessWidget {
  const _StickerPreviewOverlay({
    required this.sticker,
    required this.owned,
    required this.onClose,
  });

  final StickerEntry sticker;
  final bool owned;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final side = (size.shortestSide * 0.72).clamp(220.0, 380.0);
    final image = Image.asset(
      sticker.assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: side,
                      height: side,
                      child: owned
                          ? image
                          : ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.05, 0.05, 0.05, 0, 18,
                                0.05, 0.05, 0.05, 0, 18,
                                0.08, 0.08, 0.1, 0, 28,
                                0, 0, 0, 0.55, 0,
                              ]),
                              child: image,
                            ),
                    ),
                    if (!owned) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Not collected yet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 12,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halbtransparentes Regel-Panel (Genshin-Stil).
class _RulesPanel extends StatelessWidget {
  const _RulesPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
            decoration: BoxDecoration(
              color: const Color(0xCC1A2438),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sticker album',
                        style: TextStyle(
                          color: Color(0xFFFFE7A0),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Finish a coloring page with the green check to earn its sticker — paint at least about 70% of the picture.\n'
                  '• Leaving without the check does not give a sticker.\n'
                  '• Completing a puzzle also earns a sticker.\n'
                  '• Each day you can open one of three gift boxes for a surprise sticker (no duplicates).\n'
                  '• Collect them all to download the free sticker pack.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
