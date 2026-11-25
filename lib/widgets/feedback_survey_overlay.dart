import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/feedback_smile_stickers.dart';
import '../l10n/app_strings.dart';
import '../providers/feedback_survey_store.dart';
import 'snap_sparkle_burst.dart';

/// Einfache einmalige Umfrage: Sticker-Smilies + optionale Lieblings-Aktivität.
class FeedbackSurveyOverlay extends StatefulWidget {
  const FeedbackSurveyOverlay({super.key, required this.onClosed});

  final VoidCallback onClosed;

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => FeedbackSurveyOverlay(
        onClosed: () => Navigator.of(ctx).maybePop(),
      ),
    );
  }

  /// Zeigt die Umfrage, wenn Zähler bereits erfüllt sind (kein erneutes Zählen).
  static Future<void> maybeShowIfEligible(BuildContext context) async {
    final store = context.read<FeedbackSurveyStore>();
    if (!store.isReady) await store.load();
    if (!store.shouldOfferSurvey || !context.mounted) return;
    await show(context);
  }

  @override
  State<FeedbackSurveyOverlay> createState() => _FeedbackSurveyOverlayState();
}

class _FeedbackSurveyOverlayState extends State<FeedbackSurveyOverlay>
    with SingleTickerProviderStateMixin {
  FeedbackSatisfaction? _satisfaction;
  FeedbackFavorite? _favorite;
  bool _submitting = false;
  final _noteCtrl = TextEditingController();

  late final AnimationController _intro;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
    );
    unawaited(_intro.forward());
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final satisfaction = _satisfaction;
    if (satisfaction == null || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    final note = _noteCtrl.text.trim();
    await context.read<FeedbackSurveyStore>().submit(
          satisfaction: satisfaction,
          favorite: _favorite,
          note: note,
        );
    if (!mounted) return;
    widget.onClosed();
  }

  Future<void> _dismiss() async {
    if (_submitting) return;
    HapticFeedback.selectionClick();
    await context.read<FeedbackSurveyStore>().markDismissed();
    if (!mounted) return;
    widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 12, 22, 12 + bottomInset),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2744),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFFFD56A).withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.feedbackSurveyTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFE7A0),
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.feedbackSurveySubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              height: 1.35,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _SmileChoice(
                                  asset: FeedbackSmileStickers.good,
                                  label: t.feedbackSmileGood,
                                  selected: _satisfaction ==
                                      FeedbackSatisfaction.good,
                                  onTap: () => setState(
                                    () => _satisfaction =
                                        FeedbackSatisfaction.good,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SmileChoice(
                                  asset: FeedbackSmileStickers.okay,
                                  label: t.feedbackSmileOkay,
                                  selected: _satisfaction ==
                                      FeedbackSatisfaction.okay,
                                  onTap: () => setState(
                                    () => _satisfaction =
                                        FeedbackSatisfaction.okay,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SmileChoice(
                                  asset: FeedbackSmileStickers.bad,
                                  label: t.feedbackSmileBad,
                                  selected: _satisfaction ==
                                      FeedbackSatisfaction.bad,
                                  onTap: () => setState(
                                    () => _satisfaction =
                                        FeedbackSatisfaction.bad,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.feedbackFavoritePrompt,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final item in [
                                (
                                  FeedbackFavorite.coloring,
                                  t.feedbackFavoriteColor
                                ),
                                (
                                  FeedbackFavorite.puzzle,
                                  t.feedbackFavoritePuzzle
                                ),
                                (
                                  FeedbackFavorite.pixel,
                                  t.feedbackFavoritePixel
                                ),
                                (
                                  FeedbackFavorite.daily,
                                  t.feedbackFavoriteDaily
                                ),
                              ])
                                _ChipChoice(
                                  label: item.$2,
                                  selected: _favorite == item.$1,
                                  onTap: () => setState(() {
                                    _favorite = _favorite == item.$1
                                        ? null
                                        : item.$1;
                                  }),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.feedbackNotePrompt,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _noteCtrl,
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 400,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: const Color(0xFFFFD56A),
                            decoration: InputDecoration(
                              hintText: t.feedbackNoteHint,
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              counterStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.06),
                              contentPadding: const EdgeInsets.all(12),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFFD56A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _satisfaction == null || _submitting
                                  ? null
                                  : () => unawaited(_submit()),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD56A),
                                foregroundColor: const Color(0xFF1A2744),
                                disabledBackgroundColor:
                                    Colors.white.withValues(alpha: 0.12),
                                disabledForegroundColor:
                                    Colors.white.withValues(alpha: 0.35),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                t.feedbackSurveySend,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => unawaited(_dismiss()),
                            child: Text(
                              t.feedbackSurveySkip,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmileChoice extends StatefulWidget {
  const _SmileChoice({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SmileChoice> createState() => _SmileChoiceState();
}

class _SmileChoiceState extends State<_SmileChoice>
    with TickerProviderStateMixin {
  late final AnimationController _sparkle;
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void didUpdateWidget(covariant _SmileChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected) {
      _sparkle.forward(from: 0);
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sparkle.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    // Kein easeOutBack hier — TweenSequence verlangt t in [0,1].
    final popScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 1)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 55,
      ),
    ]).animate(_pop);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedBuilder(
          animation: Listenable.merge([_sparkle, _pop]),
          builder: (context, child) {
            return Transform.scale(
              scale: selected ? popScale.value : 1,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFFFD56A).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFFD56A)
                    : Colors.white.withValues(alpha: 0.12),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final center = Offset(
                        constraints.maxWidth / 2,
                        constraints.maxHeight / 2,
                      );
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            widget.asset,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.emoji_emotions_outlined,
                              size: 40,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _sparkle,
                            builder: (context, _) {
                              if (_sparkle.value <= 0) {
                                return const SizedBox.shrink();
                              }
                              return SnapSparkleBurst(
                                progress: _sparkle.value,
                                center: center,
                                count: 12,
                                radius: math.min(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    ) *
                                    0.55,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFFFE7A0)
                        : Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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

class _ChipChoice extends StatefulWidget {
  const _ChipChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ChipChoice> createState() => _ChipChoiceState();
}

class _ChipChoiceState extends State<_ChipChoice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparkle;

  @override
  void initState() {
    super.initState();
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void didUpdateWidget(covariant _ChipChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected) {
      _sparkle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFD56A).withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFD56A)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFFFE7A0)
                      : Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _sparkle,
                  builder: (context, _) {
                    if (_sparkle.value <= 0) {
                      return const SizedBox.shrink();
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SnapSparkleBurst(
                          progress: _sparkle.value,
                          center: Offset(
                            constraints.maxWidth / 2,
                            constraints.maxHeight / 2,
                          ),
                          count: 8,
                          radius: 28,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
