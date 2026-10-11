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
import '../utils/image_source.dart';

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

  // Pergament-Buch Palette
  static const _parchment = Color(0xFFF3E6C8);
  static const _parchmentDeep = Color(0xFFE8D4A8);
  static const _ink = Color(0xFF4A3208);
  static const _sepiaEdge = Color(0xFFC4A46A);

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
        final bytes = await loadImageBytes(s.assetPath);
        final name = s.assetPath.split('/').last;
        final out = File('${dir.path}/$name');
        await out.writeAsBytes(bytes);
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
      color: Colors.black.withValues(alpha: 0.55),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _showRules ? 0.28 : 1,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  landscape ? 20 : 16,
                  landscape ? 6 : 8,
                  landscape ? 20 : 16,
                  landscape ? 6 : 10,
                ),
                child: Column(
                  children: [
                    // Nur Info/Close — Titel sitzt am Album-Block.
                    Row(
                      children: [
                        _AlbumChromeButton(
                          tooltip: 'Rules',
                          icon: Icons.info_outline_rounded,
                          onPressed: () =>
                              setState(() => _showRules = true),
                        ),
                        const Spacer(),
                        _AlbumChromeButton(
                          tooltip: 'Close',
                          icon: Icons.close_rounded,
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final gap = landscape ? 6.0 : 10.0;
                          final inset = landscape ? 10.0 : 14.0;
                          final titleSize = landscape ? 17.0 : 20.0;
                          final countSize = landscape ? 15.0 : 18.0;
                          final titleGap = landscape ? 4.0 : 8.0;
                          final countGap = landscape ? 4.0 : 8.0;
                          final titleH = titleSize + 4;
                          final countH = countSize + 4;
                          final exportH = store.isComplete ? 40.0 : 0.0;
                          final chromeExtras = titleH +
                              titleGap +
                              countGap +
                              countH +
                              exportH +
                              6; // Slack gegen Subpixel-Overflow

                          final maxW = constraints.maxWidth;
                          final maxPanelH =
                              (constraints.maxHeight - chromeExtras)
                                  .clamp(64.0, double.infinity);
                          final innerMaxW = (maxW - inset * 2)
                              .clamp(0.0, double.infinity);
                          final innerMaxH = (maxPanelH - inset * 2)
                              .clamp(0.0, double.infinity);
                          final cellFromW =
                              (innerMaxW - gap * (_cols - 1)) / _cols;
                          final cellFromH =
                              (innerMaxH - gap * (_rows - 1)) / _rows;
                          var cell = cellFromW < cellFromH
                              ? cellFromW
                              : cellFromH;
                          final maxCell = landscape ? 110.0 : 140.0;
                          if (cell > maxCell) cell = maxCell;
                          if (cell < 36) cell = 36;
                          // Nochmals gegen Budget kappen (min-cell darf nicht sprengen).
                          final gridW = cell * _cols + gap * (_cols - 1);
                          var gridH = cell * _rows + gap * (_rows - 1);
                          var panelW = gridW + inset * 2;
                          var panelH = gridH + inset * 2;
                          if (panelH > maxPanelH) {
                            final scale = maxPanelH / panelH;
                            panelW *= scale;
                            panelH = maxPanelH;
                          }
                          if (panelW > maxW) {
                            final scale = maxW / panelW;
                            panelW = maxW;
                            panelH *= scale;
                          }

                          final titleStyle = TextStyle(
                            color: const Color(0xFFFFE7A0),
                            fontWeight: FontWeight.w800,
                            fontSize: titleSize,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 8,
                              ),
                            ],
                          );
                          final countStyle = TextStyle(
                            color: const Color(0xFFFFE7A0),
                            fontSize: countSize,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 8,
                              ),
                            ],
                          );

                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sticker album',
                                  textAlign: TextAlign.center,
                                  style: titleStyle,
                                ),
                                SizedBox(height: titleGap),
                                SizedBox(
                                  width: panelW,
                                  height: panelH,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color:
                                          _parchment.withValues(alpha: 0.96),
                                      borderRadius:
                                          BorderRadius.circular(22),
                                      border: Border.all(
                                        color: _sepiaEdge
                                            .withValues(alpha: 0.85),
                                        width: 1.8,
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
                                            padding: EdgeInsets.all(inset),
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
                                              itemBuilder: (context, i) {
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
                                SizedBox(height: countGap),
                                Text(
                                  '${store.ownedCount} / ${store.totalCount}',
                                  style: countStyle,
                                ),
                                if (store.isComplete)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: TextButton.icon(
                                      onPressed: () => _exportPack(store),
                                      icon: const Icon(
                                        Icons.download_rounded,
                                      ),
                                      label: const Text('Sticker pack'),
                                      style: TextButton.styleFrom(
                                        backgroundColor: _parchmentDeep,
                                        foregroundColor: _ink,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
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

/// Heller Chrome-Button über dem Album (dunkler Hub-Hintergrund).
class _AlbumChromeButton extends StatelessWidget {
  const _AlbumChromeButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xE6FFF6E0),
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: const Color(0x88000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 24,
              color: const Color(0xFF3A2810),
            ),
          ),
        ),
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

  static const _lockedFilter = ColorFilter.matrix(<double>[
    0.32, 0.28, 0.2, 0, 55,
    0.28, 0.3, 0.2, 0, 48,
    0.22, 0.22, 0.18, 0, 40,
    0, 0, 0, 0.5, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: imageProviderFor(sticker.assetPath),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    final body = owned
        ? image
        : ColorFiltered(
            colorFilter: _lockedFilter,
            child: image,
          );
    return Material(
      color: const Color(0xFFE8D4A8).withValues(alpha: 0.55),
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

  static const _lockedFilter = ColorFilter.matrix(<double>[
    0.32, 0.28, 0.2, 0, 55,
    0.28, 0.3, 0.2, 0, 48,
    0.22, 0.22, 0.18, 0, 40,
    0, 0, 0, 0.5, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final side = (size.shortestSide * 0.72).clamp(220.0, 380.0);
    final image = Image(
      image: imageProviderFor(sticker.assetPath),
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
                              colorFilter: _lockedFilter,
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

/// Halbtransparentes Regel-Panel (Pergament).
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
              color: const Color(0xF5F3E6C8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFC4A46A).withValues(alpha: 0.9),
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
                          color: Color(0xFF4A3208),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF4A3208),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Each day when you open the app you get a daily surprise — pick one of three gift boxes for a reward sticker.\n'
                  '• Every sticker can only be unlocked once — no duplicates.\n'
                  '• Collect them all to download the free sticker pack.',
                  style: TextStyle(
                    color: Color(0xFF4A3208),
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
