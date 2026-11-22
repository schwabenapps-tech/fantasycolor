import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/coloring_page.dart';
import '../models/puzzle_settings.dart';
import '../painting/jigsaw_layout.dart';
import '../screens/puzzle_screen.dart';
import '../utils/app_orientations.dart';
import '../widgets/coloring_page_image.dart';
import '../widgets/silver_back_button.dart';

/// Auswahl aus der Puzzle-Vorschau (Play).
typedef PuzzlePreviewChoice = ({
  PuzzleDifficulty difficulty,
  PuzzlePieceStyle style,
});

/// Großes Puzzle-Vorschaubild mit Schnittlinien — als Overlay, kein eigener Screen.
class PuzzlePreviewOverlay {
  PuzzlePreviewOverlay._();

  /// `null` = abgebrochen; sonst gewählte Einstellungen + Play.
  static Future<PuzzlePreviewChoice?> show(
    BuildContext context,
    ColoringPage page, {
    Set<PuzzleTier> lockedTiers = const {},
    Set<PuzzleDifficulty> lockedDifficulties = const {},
    PuzzleDifficulty? initialDifficulty,
  }) {
    HapticFeedback.selectionClick();
    return showGeneralDialog<PuzzlePreviewChoice>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Puzzle preview',
      // Opak: Hub dahinter darf technisch mitdrehen — bleibt unsichtbar.
      barrierColor: const Color(0xFF0B1524),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _PuzzlePreviewBody(
          page: page,
          lockedTiers: lockedTiers,
          lockedDifficulties: lockedDifficulties,
          initialDifficulty: initialDifficulty,
          onClose: () => Navigator.of(context).pop(),
          onPlay: (choice) => Navigator.of(context).pop(choice),
        );
      },
      transitionBuilder: (context, anim, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _PuzzlePreviewBody extends StatefulWidget {
  const _PuzzlePreviewBody({
    required this.page,
    required this.onClose,
    required this.onPlay,
    this.lockedTiers = const {},
    this.lockedDifficulties = const {},
    this.initialDifficulty,
  });

  final ColoringPage page;
  final VoidCallback onClose;
  final ValueChanged<PuzzlePreviewChoice> onPlay;
  final Set<PuzzleTier> lockedTiers;
  final Set<PuzzleDifficulty> lockedDifficulties;
  final PuzzleDifficulty? initialDifficulty;

  @override
  State<_PuzzlePreviewBody> createState() => _PuzzlePreviewBodyState();
}

class _PuzzlePreviewBodyState extends State<_PuzzlePreviewBody> {
  PuzzleDifficulty _difficulty = PuzzleDifficulty.medium42;
  PuzzlePieceStyle _style = PuzzlePieceStyle.jigsaw;
  bool _ready = false;

  bool _isTierLocked(PuzzleTier tier) => widget.lockedTiers.contains(tier);

  bool _isDifficultyLocked(PuzzleDifficulty d) =>
      _isTierLocked(d.tier) || widget.lockedDifficulties.contains(d);

  PuzzleDifficulty _firstAllowedInTier(PuzzleTier tier) {
    for (final d in PuzzleDifficulty.forTier(tier)) {
      if (!_isDifficultyLocked(d)) return d;
    }
    // Fallback: irgendeine erlaubte Difficulty.
    for (final d in PuzzleDifficulty.values) {
      if (!_isDifficultyLocked(d)) return d;
    }
    return PuzzleDifficulty.medium42;
  }

  PuzzleDifficulty _clampDifficulty(PuzzleDifficulty d) {
    if (!_isDifficultyLocked(d)) return d;
    if (!_isTierLocked(d.tier)) return _firstAllowedInTier(d.tier);
    for (final tier in PuzzleTier.values) {
      if (_isTierLocked(tier)) continue;
      return _firstAllowedInTier(tier);
    }
    return PuzzleDifficulty.medium42;
  }

  @override
  void initState() {
    super.initState();
    unawaited(AppOrientations.enterPlay());
    unawaited(_loadPrefs());
  }

  @override
  void dispose() {
    unawaited(AppOrientations.leavePlay());
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final saved = await PuzzlePreferences.load();
    if (!mounted) return;
    final forced = widget.initialDifficulty;
    setState(() {
      _difficulty = _clampDifficulty(forced ?? saved.difficulty);
      _style = saved.style;
      _ready = true;
    });
  }

  Future<void> _persist() async {
    await PuzzlePreferences.save(
      difficulty: _difficulty,
      style: _style,
    );
  }

  void _setTier(PuzzleTier tier) {
    if (_isTierLocked(tier)) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_isDifficultyLocked(_difficulty) || _difficulty.tier != tier) {
        _difficulty = _firstAllowedInTier(tier);
      }
    });
    unawaited(_persist());
  }

  void _setDifficulty(PuzzleDifficulty difficulty) {
    if (_isDifficultyLocked(difficulty)) return;
    HapticFeedback.selectionClick();
    setState(() => _difficulty = difficulty);
    unawaited(_persist());
  }

  void _setStyle(PuzzlePieceStyle style) {
    HapticFeedback.selectionClick();
    setState(() => _style = style);
    unawaited(_persist());
  }

  Future<void> _play() async {
    await _persist();
    if (!mounted) return;
    widget.onPlay((difficulty: _difficulty, style: _style));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final sideBySide = landscape || size.width >= 700;
    final aspect = widget.page.aspectRatio <= 0 ? 0.78 : widget.page.aspectRatio;

    final preview = _PreviewImage(
      page: widget.page,
      aspect: aspect,
      difficulty: _difficulty,
      style: _style,
      ready: _ready,
    );

    final settings = _PreviewSettingsPanel(
      difficulty: _difficulty,
      style: _style,
      lockedTiers: widget.lockedTiers,
      lockedDifficulties: widget.lockedDifficulties,
      onTier: _setTier,
      onDifficulty: _setDifficulty,
      onStyle: _setStyle,
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PreviewActionButton(
          label: 'Play',
          icon: Icons.extension_rounded,
          filled: true,
          onPressed: () => unawaited(_play()),
        ),
        const SizedBox(width: 12),
        _PreviewActionButton(
          label: 'Close',
          icon: Icons.close_rounded,
          filled: false,
          onPressed: widget.onClose,
        ),
      ],
    );

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 52, 12, 12),
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: sideBySide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 58,
                            child: Column(
                              children: [
                                Expanded(child: preview),
                                const SizedBox(height: 14),
                                actions,
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 42,
                            child: settings,
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(flex: 55, child: preview),
                          const SizedBox(height: 10),
                          Expanded(flex: 45, child: settings),
                          const SizedBox(height: 12),
                          actions,
                        ],
                      ),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: SilverBackButton(onPressed: widget.onClose),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({
    required this.page,
    required this.aspect,
    required this.difficulty,
    required this.style,
    required this.ready,
  });

  final ColoringPage page;
  final double aspect;
  final PuzzleDifficulty difficulty;
  final PuzzlePieceStyle style;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var previewW = constraints.maxWidth;
        var previewH = previewW / aspect;
        if (previewH > constraints.maxHeight) {
          previewH = constraints.maxHeight;
          previewW = previewH * aspect;
        }

        return Center(
          child: SizedBox(
            width: previewW,
            height: previewH,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.white,
                      child: ColoringPageImage(
                        page: page,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    if (ready)
                      CustomPaint(
                        painter: _PuzzleSeamPainter(
                          aspect: aspect,
                          seed: page.id.hashCode,
                          targetPieces: difficulty.targetPieces,
                          style: style,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PreviewSettingsPanel extends StatelessWidget {
  const _PreviewSettingsPanel({
    required this.difficulty,
    required this.style,
    required this.lockedTiers,
    required this.lockedDifficulties,
    required this.onTier,
    required this.onDifficulty,
    required this.onStyle,
  });

  final PuzzleDifficulty difficulty;
  final PuzzlePieceStyle style;
  final Set<PuzzleTier> lockedTiers;
  final Set<PuzzleDifficulty> lockedDifficulties;
  final ValueChanged<PuzzleTier> onTier;
  final ValueChanged<PuzzleDifficulty> onDifficulty;
  final ValueChanged<PuzzlePieceStyle> onStyle;

  @override
  Widget build(BuildContext context) {
    final pieceChoices = PuzzleDifficulty.forTier(difficulty.tier);

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
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
              color: const Color(0xFFFFD56A).withValues(alpha: 0.18),
              blurRadius: 22,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Puzzle-Zauber',
                style: TextStyle(
                  color: Color(0xFFFFE7A0),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lockedTiers.isEmpty
                    ? 'Wie magisch soll dein Puzzle sein?'
                    : 'Für die Tagesaufgabe: Leicht ist gesperrt.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 14),
              _sectionLabel('Abenteuer-Stufe'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tier in PuzzleTier.values)
                    _PreviewChip(
                      label: tier.label,
                      selected: difficulty.tier == tier,
                      locked: lockedTiers.contains(tier),
                      onTap: () => onTier(tier),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _sectionLabel('Teile'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in pieceChoices)
                    _PreviewChip(
                      label: '${d.targetPieces}',
                      selected: difficulty == d,
                      locked: lockedDifficulties.contains(d) ||
                          lockedTiers.contains(d.tier),
                      onTap: () => onDifficulty(d),
                    ),
                ],
              ),
              if (difficulty.allowsZoom) ...[
                const SizedBox(height: 8),
                Text(
                  'Tipp: Mit zwei Fingern zoomen',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _sectionLabel('Zauber-Form'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in PuzzlePieceStyle.values)
                    _PreviewChip(
                      label: s.label,
                      selected: style == s,
                      onTap: () => onStyle(s),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                style.hint,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: const Color(0xFFFFD56A).withValues(alpha: 0.9),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final Gradient? gradient = (!locked && selected)
        ? LinearGradient(
            colors: [
              const Color(0xFFFFD56A).withValues(alpha: 0.35),
              const Color(0xFFFFB347).withValues(alpha: 0.22),
            ],
          )
        : null;
    return Opacity(
      opacity: locked ? 0.38 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: gradient,
              color: locked
                  ? Colors.white.withValues(alpha: 0.05)
                  : (selected ? null : Colors.white.withValues(alpha: 0.07)),
              border: Border.all(
                color: locked
                    ? Colors.white.withValues(alpha: 0.15)
                    : selected
                        ? const Color(0xFFFFD56A)
                        : Colors.white.withValues(alpha: 0.2),
                width: selected && !locked ? 1.6 : 1,
              ),
              boxShadow: selected && !locked
                  ? [
                      BoxShadow(
                        color:
                            const Color(0xFFFFD56A).withValues(alpha: 0.22),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locked) ...[
                  Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected && !locked
                        ? const Color(0xFFFFF3C4)
                        : Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _PreviewActionButton extends StatelessWidget {
  const _PreviewActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? const Color(0xFFFFE0A8) : const Color(0xFFF4F0EA);
    const fg = Color(0xFF3A2810);
    return Material(
      color: bg,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PuzzleSeamPainter extends CustomPainter {
  _PuzzleSeamPainter({
    required this.aspect,
    required this.seed,
    required this.targetPieces,
    required this.style,
  });

  final double aspect;
  final int seed;
  final int targetPieces;
  final PuzzlePieceStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = PuzzleScreen.gridForDisplayAspect(
      aspect,
      targetCount: targetPieces,
    );
    final layout = JigsawLayout(
      columns: grid.cols,
      rows: grid.rows,
      style: style,
      random: math.Random(seed),
    );

    final density = math.sqrt(targetPieces / 30.0).clamp(0.7, 2.2);
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.6 / density).clamp(1.1, 2.6)
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeJoin = StrokeJoin.round;
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.35 / density).clamp(0.7, 1.35)
      ..color = Colors.white.withValues(alpha: 0.88)
      ..strokeJoin = StrokeJoin.round;

    for (var row = 0; row < layout.rows; row++) {
      for (var col = 0; col < layout.columns; col++) {
        final path = layout.piecePath(
          col: col,
          row: row,
          boardSize: size,
        );
        canvas.drawPath(path, shadow);
        canvas.drawPath(path, seam);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PuzzleSeamPainter oldDelegate) =>
      oldDelegate.aspect != aspect ||
      oldDelegate.seed != seed ||
      oldDelegate.targetPieces != targetPieces ||
      oldDelegate.style != style;
}
