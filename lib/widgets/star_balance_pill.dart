import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/star_wallet_store.dart';
import 'earn_stars_sheet.dart';

/// Stern-Anzahl in der Hub-Topbar (zählt bei Zuwachs hoch).
class StarBalancePill extends StatefulWidget {
  const StarBalancePill({
    super.key,
    this.compact = false,
  });

  final bool compact;

  static const asset = 'assets/images/sternicon.png';

  static const fill = Color(0xFFE8C56A);
  static const border = Color(0xFFC9A03A);
  static const glow = Color(0xFFB8862B);
  static const ink = Color(0xFF4A3208);

  @override
  State<StarBalancePill> createState() => _StarBalancePillState();
}

class _StarBalancePillState extends State<StarBalancePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  int _displayed = 0;
  int _from = 0;
  int _to = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() {
      final v = _from + (_to - _from) * _anim.value;
      setState(() => _displayed = v.round());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final balance = context.watch<StarWalletStore>().balance;
    if (!_ready) {
      _ready = true;
      _displayed = balance;
      _from = balance;
      _to = balance;
      return;
    }
    if (balance == _to) return;
    _from = _displayed;
    _to = balance;
    if (balance > _from) {
      _ctrl.forward(from: 0);
    } else {
      _ctrl.stop();
      _displayed = balance;
      _from = balance;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.compact ? 32.0 : 36.0;
    final radius = BorderRadius.circular(22);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: StarBalancePill.glow.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: StarBalancePill.fill.withValues(alpha: 0.94),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => EarnStarsSheet.show(context),
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: StarBalancePill.border.withValues(alpha: 0.95),
                width: 1.4,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              widget.compact ? 6 : 8,
              widget.compact ? 4 : 5,
              widget.compact ? 8 : 12,
              widget.compact ? 4 : 5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  StarBalancePill.asset,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
                SizedBox(width: widget.compact ? 4 : 6),
                Text(
                  '$_displayed',
                  style: TextStyle(
                    color: StarBalancePill.ink,
                    fontSize: widget.compact ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
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
