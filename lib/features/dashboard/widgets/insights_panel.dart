import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../models/analytics.dart';
import '../../../widgets/app_card.dart';

/// Generated observations about the current month.
class InsightsPanel extends StatelessWidget {
  const InsightsPanel({
    super.key,
    required this.insights,
    this.limit,
  });

  final List<Insight> insights;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const _InsightsEmpty();
    }

    final items = limit == null
        ? insights
        : insights.take(limit!).toList(growable: false);

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : Gap.sm),
            child: _InsightTile(insight: items[i]),
          ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    final color = switch (insight.tone) {
      InsightTone.positive => palette.income,
      InsightTone.negative => palette.expense,
      InsightTone.warning => palette.warning,
      InsightTone.neutral => palette.savings,
    };

    return AppCard(
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: AppIcons.resolve(insight.iconKey),
            color: color,
            size: 38,
            iconSize: 18,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.message, style: theme.textTheme.bodyMedium),
                if (insight.detail != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    insight.detail!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: palette.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when there genuinely is not enough data to say anything true.
class _InsightsEmpty extends StatelessWidget {
  const _InsightsEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    return AppCard(
      child: Row(
        children: [
          IconBadge(
            icon: Icons.auto_awesome_rounded,
            color: palette.textTertiary,
            size: 38,
            iconSize: 18,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No insights yet', style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  'Add more transactions to generate meaningful insights.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: palette.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
