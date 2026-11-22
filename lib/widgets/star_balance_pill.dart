import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/star_wallet_store.dart';
import 'earn_stars_sheet.dart';

/// Stern-Anzahl in der Hub-Topbar.
class StarBalancePill extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final balance = context.watch<StarWalletStore>().balance;
    final iconSize = compact ? 24.0 : 28.0;
    final radius = BorderRadius.circular(22);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: fill.withValues(alpha: 0.94),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => EarnStarsSheet.show(context),
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: border.withValues(alpha: 0.95),
                width: 1.4,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              compact ? 6 : 8,
              compact ? 4 : 5,
              compact ? 8 : 12,
              compact ? 4 : 5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  asset,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
                SizedBox(width: compact ? 4 : 6),
                Text(
                  '$balance',
                  style: TextStyle(
                    color: ink,
                    fontSize: compact ? 14 : 16,
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
