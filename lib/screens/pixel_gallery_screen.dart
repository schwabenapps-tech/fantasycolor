import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/puzzle_images_loader.dart';
import '../models/coloring_page.dart';
import '../models/pixel_puzzle.dart';
import '../providers/pixel_mode_unlock_store.dart';
import '../providers/pixel_progress_store.dart';
import '../services/ads_service.dart';
import '../utils/app_layout.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/progress_badge.dart';
import '../widgets/silver_back_button.dart';
import 'pixel_paint_screen.dart';

/// Galerie für den fortgeschrittenen Pixel-/Malen-nach-Zahlen-Modus.
///
/// Nutzt die Puzzle-Bilder als Vorlagen für quantisierte Pixel-Bilder.
class PixelGalleryScreen extends StatefulWidget {
  const PixelGalleryScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

  @override
  State<PixelGalleryScreen> createState() => _PixelGalleryScreenState();
}

class _PixelGalleryScreenState extends State<PixelGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Future<List<ColoringPage>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = loadPuzzleImages();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _openPage(ColoringPage page) async {
    HapticFeedback.selectionClick();
    final store = context.read<PixelProgressStore>();
    final existing = await store.loadSnapshot(page.id);

    if (!mounted) return;

    if (existing != null && !existing.completed && existing.filledCount > 0) {
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: PixelPaintScreen(
                page: page,
                difficulty: PixelDifficulty.standard,
                resumeSnapshot: existing,
              ),
            );
          },
        ),
      );
      return;
    }

    if (existing != null) {
      await store.clearProgress(page.id);
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: PixelPaintScreen(
              page: page,
              difficulty: PixelDifficulty.standard,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = AppLayout.of(context);
    final tileHeight = layout.galleryTileHeight;
    final tileWidth = layout.galleryTileWidth;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            PixelGalleryScreen.backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Stack(
                children: [
                  FutureBuilder<List<ColoringPage>>(
                    future: _pagesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xFFE8EEF8),
                            ),
                          ),
                        );
                      }

                      final pages = snapshot.data ?? const <ColoringPage>[];
                      if (pages.isEmpty) {
                        return const Center(
                          child: Text(
                            'Keine Pixel-Bilder gefunden',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          SizedBox(height: layout.galleryTopSpacer * 0.55),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: size.width * 0.08,
                            ),
                            child: const Text(
                              'Malen nach Zahlen',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFFFE7A0),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Wähle ein Bild · tippe die Nummern an',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: const Alignment(0, 0.35),
                              child: SizedBox(
                                height: tileHeight,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: size.width * 0.055,
                                  ),
                                  itemCount: pages.length,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(width: size.width * 0.03),
                                  itemBuilder: (context, index) {
                                    final page = pages[index];
                                    final pixelProgress =
                                        context.watch<PixelProgressStore>();
                                    return _PixelPageTile(
                                      page: page,
                                      width: tileWidth,
                                      height: tileHeight,
                                      hasProgress:
                                          pixelProgress.hasProgress(page.id),
                                      isCompleted:
                                          pixelProgress.isCompleted(page.id),
                                      progressVersion:
                                          pixelProgress.versionOf(page.id),
                                      previewFile: pixelProgress
                                          .previewFileFor(page.id),
                                      onTap: () => _openPage(page),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.03),
                        ],
                      );
                    },
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: SilverBackButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nur Freischaltung (Interstitial), ohne Navigation.
Future<void> openPixelModeUnlockOnly(BuildContext context) async {
  final unlock = context.read<PixelModeUnlockStore>();
  if (unlock.isUnlocked) return;
  await AdsService.showInterstitial();
  await unlock.unlock();
}

/// Einstieg aus der normalen Mal-Galerie: Freischaltung per Interstitial.
Future<void> openPixelModeFromGallery(BuildContext context) async {
  final unlock = context.read<PixelModeUnlockStore>();
  if (!unlock.isUnlocked) {
    final wantsUnlock = await showPixelUnlockDialog(context);
    if (wantsUnlock != true || !context.mounted) return;
    await openPixelModeUnlockOnly(context);
    if (!context.mounted) return;
  }

  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: const PixelGalleryScreen(),
        );
      },
    ),
  );
}

Future<bool?> showPixelUnlockDialog(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Freischalten',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, anim, secondary) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.7,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2B3B66),
                        Color(0xFF1A2744),
                        Color(0xFF121C33),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFD56A).withValues(alpha: 0.55),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD56A).withValues(alpha: 0.2),
                        blurRadius: 28,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.grid_on_rounded,
                          color: Color(0xFFFFD56A),
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Fortgeschrittener Modus',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFFE7A0),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Malen nach Zahlen mit Pixelbildern.\n'
                          'Kurz eine Werbung anschauen — dann ist der Modus freigeschaltet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _PixelDialogButton(
                                label: 'Später',
                                filled: false,
                                onPressed: () => Navigator.pop(context, false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PixelDialogButton(
                                label: 'Freischalten',
                                filled: true,
                                onPressed: () => Navigator.pop(context, true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PixelPageTile extends StatelessWidget {
  const _PixelPageTile({
    required this.page,
    required this.width,
    required this.height,
    required this.hasProgress,
    required this.isCompleted,
    required this.progressVersion,
    required this.previewFile,
    required this.onTap,
  });

  final ColoringPage page;
  final double width;
  final double height;
  final bool hasProgress;
  final bool isCompleted;
  final int progressVersion;
  final File? previewFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF8E8),
                Color(0xFFFFE0A0),
                Color(0xFFE8B86A),
                Color(0xFFFFF0C8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD56A).withValues(alpha: 0.3),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: Colors.white,
                      child: previewFile != null
                          ? Image.file(
                              previewFile!,
                              key: ValueKey(
                                'pixel_preview_${page.id}_$progressVersion',
                              ),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) => ColoringPageImage(
                                page: page,
                                fit: BoxFit.cover,
                              ),
                            )
                          : ColoringPageImage(
                              page: page,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(14),
                            ),
                    ),
                  ),
                ),
                if (hasProgress)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: ProgressBadge(
                      label: isCompleted ? 'Fertig' : 'Weiter',
                      done: isCompleted,
                    ),
                  ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_on_rounded,
                            size: 14,
                            color: Color(0xFFFFE7A0),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Pixel',
                            style: TextStyle(
                              color: Color(0xFFFFE7A0),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _PixelDialogButton extends StatelessWidget {
  const _PixelDialogButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: filled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF0C2),
                      Color(0xFFFFD56A),
                      Color(0xFFE0A93A),
                    ],
                  )
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: filled
                  ? const Color(0xFFFFE7A0)
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: filled
                    ? const Color(0xFF2A2410)
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
