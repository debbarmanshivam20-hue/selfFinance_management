import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../models/analytics.dart';
import '../../../models/enums.dart';

/// The headline card: what is available to spend right now, and the three
/// totals it is derived from.
class BalanceHeroCard extends StatelessWidget {
  const BalanceHeroCard({
    super.key,
    required this.totals,
    required this.formatter,
    this.onInfo,
  });

  final PeriodTotals totals;
  final MoneyFormatter formatter;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;
    final available = totals.available;

    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        borderRadius: Corners.card,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.brandGradient,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.brandGradient.last.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Available balance',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.82)),
              ),
              const SizedBox(width: Gap.xs),
              InkWell(
                onTap: onInfo,
                borderRadius: BorderRadius.circular(Corners.pill),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: Corners.chip,
                ),
                child: Text(
                  '${totals.transactionCount} entries',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatter.format(available),
              style: AppType.display(38).copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Net worth ${formatter.format(totals.netWorth)} · '
            '${formatter.format(totals.savings)} set aside',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Gap.xl),
          Container(
            padding: const EdgeInsets.symmetric(vertical: Gap.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: Corners.tile,
            ),
            child: Row(
              children: [
                _HeroStat(
                  label: 'Income',
                  value: formatter.compact(totals.income),
                  icon: TransactionType.income.icon,
                ),
                _HeroDivider(),
                _HeroStat(
                  label: 'Expenses',
                  value: formatter.compact(totals.expense),
                  icon: TransactionType.expense.icon,
                ),
                _HeroDivider(),
                _HeroStat(
                  label: 'Savings',
                  value: formatter.compact(totals.savings),
                  icon: TransactionType.savings.icon,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: Gap.xs),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}
