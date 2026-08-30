import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/money.dart';
import '../models/enums.dart';

/// Renders a monetary value with the type's colour and sign.
///
/// Colour alone never carries the meaning: the `+`/`-` prefix and the type
/// label elsewhere in the row keep the information available to users who
/// cannot distinguish red from green.
class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.money,
    required this.formatter,
    this.type,
    this.size = 16,
    this.weight = 700,
    this.color,
    this.showSign = true,
    this.compact = false,
    this.showDecimals = true,
  });

  final Money money;
  final MoneyFormatter formatter;
  final TransactionType? type;
  final double size;
  final double weight;
  final Color? color;
  final bool showSign;
  final bool compact;
  final bool showDecimals;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;

    final resolvedColor = color ??
        switch (type) {
          TransactionType.income => palette.income,
          TransactionType.expense => palette.expense,
          TransactionType.savings => palette.savings,
          TransactionType.transfer => palette.transfer,
          null => palette.textPrimary,
        };

    final body = compact
        ? formatter.compact(money)
        : formatter.format(money, showDecimals: showDecimals);
    final prefix = (showSign && type != null) ? type!.sign : '';

    return Text(
      '$prefix$body',
      style: AppType.amount(size, weight: weight).copyWith(color: resolvedColor),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: _semanticsLabel(body),
    );
  }

  String _semanticsLabel(String body) {
    final direction = switch (type) {
      TransactionType.income => 'income',
      TransactionType.expense => 'expense',
      TransactionType.savings => 'savings',
      TransactionType.transfer => 'transfer',
      null => null,
    };
    return direction == null ? body : '$body $direction';
  }
}

/// Up/down percentage badge used next to period totals.
class TrendBadge extends StatelessWidget {
  const TrendBadge({
    super.key,
    required this.percentChange,
    this.upIsGood = true,
    this.caption,
  });

  /// `null` renders nothing - there is no previous period to compare against.
  final double? percentChange;
  final bool upIsGood;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final change = percentChange;
    if (change == null) return const SizedBox.shrink();

    final palette = context.finance;
    final theme = Theme.of(context);
    final isUp = change >= 0;
    final isGood = isUp == upIsGood;
    final color = change.abs() < 0.5
        ? palette.textTertiary
        : (isGood ? palette.positive : palette.expense);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: Corners.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: Gap.xs),
          Text(
            '${change.abs().toStringAsFixed(change.abs() >= 10 ? 0 : 1)}%'
            '${caption == null ? '' : ' $caption'}',
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
