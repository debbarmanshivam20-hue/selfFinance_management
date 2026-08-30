import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/money.dart';
import '../../../models/analytics.dart';
import '../../../models/enums.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/progress.dart';

/// This month at a glance: the three totals, the savings rate, and how
/// spending compares with the previous month.
class PeriodSummaryCard extends StatelessWidget {
  const PeriodSummaryCard({
    super.key,
    required this.totals,
    required this.formatter,
    required this.title,
    this.expenseChange,
    this.onTap,
  });

  final PeriodTotals totals;
  final MoneyFormatter formatter;
  final String title;
  final double? expenseChange;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;
    final savingsRate = totals.savingsRate;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              TrendBadge(
                percentChange: expenseChange,
                upIsGood: false,
                caption: 'spend',
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Income',
                  money: totals.income,
                  type: TransactionType.income,
                  formatter: formatter,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Expenses',
                  money: totals.expense,
                  type: TransactionType.expense,
                  formatter: formatter,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Savings',
                  money: totals.savings,
                  type: TransactionType.savings,
                  formatter: formatter,
                ),
              ),
            ],
          ),
          if (savingsRate != null) ...[
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                Text(
                  'Savings rate',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: palette.textTertiary),
                ),
                const Spacer(),
                Text(
                  '${savingsRate.clamp(0, 999).toStringAsFixed(0)}% of income',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: palette.savings),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            ProgressTrack(
              value: (savingsRate / 100).clamp(0.0, 1.0),
              color: palette.savings,
              height: 7,
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.money,
    required this.type,
    required this.formatter,
  });

  final String label;
  final Money money;
  final TransactionType type;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(type.icon, size: 12, color: palette.textTertiary),
            const SizedBox(width: Gap.xs),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: palette.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AmountText(
            money: money,
            formatter: formatter,
            type: type,
            size: 17,
            showSign: false,
            showDecimals: false,
          ),
        ),
      ],
    );
  }
}

/// Small "today / this week" tiles under the hero card.
class QuickStatTile extends StatelessWidget {
  const QuickStatTile({
    super.key,
    required this.label,
    required this.money,
    required this.formatter,
    required this.icon,
    required this.color,
  });

  final String label;
  final Money money;
  final MoneyFormatter formatter;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    return AppCard(
      padding: const EdgeInsets.all(Gap.md),
      semanticLabel: '$label ${formatter.format(money)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: icon, color: color, size: 32, iconSize: 16),
          const SizedBox(height: Gap.md),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: palette.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatter.format(money, showDecimals: false),
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
