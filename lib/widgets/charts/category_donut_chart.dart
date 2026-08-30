import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/money.dart';
import '../../models/analytics.dart';
import '../app_card.dart';

/// Doughnut breakdown of spending by category, with the total in the middle.
class CategoryDonutChart extends StatefulWidget {
  const CategoryDonutChart({
    super.key,
    required this.categories,
    required this.formatter,
    required this.total,
    this.centerLabel = 'Total spent',
  });

  final List<CategoryTotal> categories;
  final MoneyFormatter formatter;
  final Money total;
  final String centerLabel;

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    // Beyond eight slices the chart becomes unreadable, so the tail is rolled
    // into a single "Other" wedge rather than shown as slivers.
    final slices = _slices();
    final highlighted =
        (_touchedIndex >= 0 && _touchedIndex < slices.length)
            ? slices[_touchedIndex]
            : null;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2.5,
            centerSpaceRadius: 62,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(
              enabled: true,
              touchCallback: (event, response) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      response?.touchedSection == null) {
                    _touchedIndex = -1;
                    return;
                  }
                  _touchedIndex =
                      response!.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            sections: [
              for (var i = 0; i < slices.length; i++)
                PieChartSectionData(
                  value: slices[i].total.minor.toDouble(),
                  color: Color(slices[i].colorValue),
                  radius: _touchedIndex == i ? 30 : 24,
                  showTitle: false,
                  borderSide: BorderSide(
                    color: palette.card,
                    width: _touchedIndex == i ? 0 : 0,
                  ),
                ),
            ],
          ),
          duration: Motion.chart,
          curve: Motion.emphasized,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (highlighted != null) ...[
              Icon(
                AppIcons.resolve(highlighted.iconKey),
                size: 18,
                color: Color(highlighted.colorValue),
              ),
              const SizedBox(height: Gap.xs),
              SizedBox(
                width: 104,
                child: Text(
                  highlighted.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: palette.textTertiary),
                ),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                widget.formatter.format(highlighted.total, showDecimals: false),
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Color(highlighted.colorValue)),
              ),
              Text(
                '${highlighted.share.toStringAsFixed(1)}%',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: palette.textTertiary),
              ),
            ] else ...[
              Text(
                widget.centerLabel,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: palette.textTertiary),
              ),
              const SizedBox(height: Gap.xs),
              SizedBox(
                width: 112,
                child: Text(
                  widget.formatter.format(widget.total, showDecimals: false),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.categories.length} categories',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: palette.textTertiary),
              ),
            ],
          ],
        ),
      ],
    );
  }

  List<CategoryTotal> _slices() {
    const maxSlices = 8;
    if (widget.categories.length <= maxSlices) return widget.categories;

    final head = widget.categories.take(maxSlices - 1).toList();
    final tail = widget.categories.skip(maxSlices - 1);
    final rest = Money.sum(tail.map((entry) => entry.total));
    final share = tail.fold<double>(0, (acc, entry) => acc + entry.share);

    return [
      ...head,
      CategoryTotal(
        categoryId: null,
        name: 'Other (${tail.length})',
        iconKey: 'more',
        colorValue: 0xFF64748B,
        total: rest,
        transactionCount:
            tail.fold<int>(0, (acc, entry) => acc + entry.transactionCount),
        share: share,
      ),
    ];
  }
}

/// Ranked list beneath the doughnut: name, amount, share and a mini bar.
class CategoryBreakdownList extends StatelessWidget {
  const CategoryBreakdownList({
    super.key,
    required this.categories,
    required this.formatter,
    this.limit,
    this.onTap,
  });

  final List<CategoryTotal> categories;
  final MoneyFormatter formatter;
  final int? limit;
  final void Function(CategoryTotal category)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;
    final items = limit == null
        ? categories
        : categories.take(limit!).toList(growable: false);

    return Column(
      children: [
        for (final entry in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: InkWell(
              onTap: onTap == null ? null : () => onTap!(entry),
              borderRadius: Corners.tile,
              child: Row(
                children: [
                  IconBadge(
                    icon: AppIcons.resolve(entry.iconKey),
                    color: Color(entry.colorValue),
                    size: 38,
                    iconSize: 18,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.name,
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            Text(
                              formatter.format(entry.total, showDecimals: false),
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.sm),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    begin: 0,
                                    end: (entry.share / 100).clamp(0.0, 1.0),
                                  ),
                                  duration: Motion.chart,
                                  curve: Motion.emphasized,
                                  builder: (context, value, _) =>
                                      LinearProgressIndicator(
                                    value: value,
                                    minHeight: 5,
                                    backgroundColor: palette.hairline,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(entry.colorValue),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            SizedBox(
                              width: 42,
                              child: Text(
                                '${entry.share.toStringAsFixed(entry.share >= 10 ? 0 : 1)}%',
                                textAlign: TextAlign.right,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: palette.textTertiary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
