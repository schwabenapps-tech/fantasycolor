import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../services/daily_quest_service.dart';

/// Glocke — bleibt sichtbar; läutet + roter Punkt nur solange offen.
class DailyQuestPill extends StatelessWidget {
  const DailyQuestPill({
    super.key,
    this.compact = false,
  });

  final bool compact;

  static const asset = 'assets/images/glocke.daily.png';

  @override
  Widget build(BuildContext context) {
    final quest = context.watch<DailyQuestService>();
    if (!quest.isReady || quest.tasks.isEmpty) {
      return const SizedBox.shrink();
    }
    final done = quest.isCompletedToday || quest.allTasksDone;
    return _RingingBell(
      compact: compact,
      active: !done,
      onTap: () {
        // ignore: discarded_futures
        quest.openOverlay(context);
      },
      semanticLabel: AppStrings.of(context).dailyQuest,
    );
  }
}

class _RingingBell extends StatefulWidget {
  const _RingingBell({
    required this.compact,
    required this.active,
    required this.onTap,
    required this.semanticLabel,
  });

  final bool compact;
  final bool active;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  State<_RingingBell> createState() => _RingingBellState();
}

class _RingingBellState extends State<_RingingBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.active) {
      _ring.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _RingingBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ring.isAnimating) {
      _ring.repeat();
    } else if (!widget.active && _ring.isAnimating) {
      _ring.stop();
      _ring.value = 0;
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 36.0 : 40.0;
    final dot = widget.compact ? 9.0 : 10.0;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: size + 6,
          height: size + 4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ring,
                  builder: (context, child) {
                    if (!widget.active) return child!;
                    final t = _ring.value;
                    final local = (t % 0.45) / 0.45;
                    final inBurst = t < 0.72;
                    final swing = inBurst
                        ? math.sin(local * math.pi * 2) * 0.22
                        : 0.0;
                    return Transform.rotate(
                      angle: swing,
                      alignment: const Alignment(0, -0.65),
                      child: child,
                    );
                  },
                  child: Opacity(
                    opacity: widget.active ? 1 : 0.72,
                    child: Image.asset(
                      DailyQuestPill.asset,
                      width: size,
                      height: size,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
              if (widget.active)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: dot,
                    height: dot,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE53935).withValues(alpha: 0.45),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
