import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/date_range.dart';
import '../core/utils/money.dart';
import '../models/enums.dart';
import '../models/transaction_view.dart';
import 'amount_text.dart';
import 'app_card.dart';

/// One row in any transaction list.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.formatter,
    this.onTap,
    this.onLongPress,
    this.showDate = true,
    this.dense = false,
  });

  final TransactionView transaction;
  final MoneyFormatter formatter;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDate;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;
    final accent = transaction.accentColor(palette);

    final subtitleParts = <String>[
      if (transaction.type == TransactionType.transfer)
        transaction.accountLabel
      else
        transaction.categoryName,
      if (showDate) DateLabels.relative(transaction.date),
      if (transaction.type != TransactionType.transfer &&
          transaction.source != null)
        transaction.source!.name,
    ];

    return Semantics(
      button: onTap != null,
      label: '${transaction.title}, '
          '${transaction.type.label}, '
          '${formatter.format(transaction.amount)}, '
          '${DateLabels.medium.format(transaction.date)}',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: dense ? Gap.sm + 2 : Gap.md,
        ),
        child: Row(
          children: [
            IconBadge(icon: transaction.icon, color: accent),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    transaction.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: palette.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AmountText(
                  money: transaction.amount,
                  formatter: formatter,
                  type: transaction.type,
                  size: 15,
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.type.label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: palette.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky-style date heading used between groups of transactions.
class TransactionDateHeader extends StatelessWidget {
  const TransactionDateHeader({
    super.key,
    required this.date,
    required this.total,
    required this.formatter,
  });

  final DateTime date;
  final Money total;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.lg, Gap.xs, Gap.sm),
      child: Row(
        children: [
          Text(
            DateLabels.relative(date),
            style: theme.textTheme.labelMedium
                ?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(child: Divider(color: palette.hairline)),
          const SizedBox(width: Gap.sm),
          Text(
            formatter.format(total, signed: true),
            style: theme.textTheme.labelMedium?.copyWith(
              color: total.isNegative ? palette.expense : palette.income,
            ),
          ),
        ],
      ),
    );
  }
}
