import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/money.dart';
import '../../models/analytics.dart';

/// Daily spending bars for one month.
///
/// Every day in the window gets a bar, including days with no spending, so the
/// shape of the month is honest rather than compressed.
class DailyExpenseChart extends StatelessWidget {
  const DailyExpenseChart({
    super.key,
    required this.points,
    required this.formatter,
  });

  final List<DailyPoint> points;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    final maxMinor = points.fold<int>(
      0,
      (acc, point) => point.amount.minor > acc ? point.amount.minor : acc,
    );
    // A flat zero axis would render as a single line; give it headroom.
    final maxY = maxMinor == 0 ? 100.0 : (maxMinor / 100) * 1.22;
    final average = points.isEmpty
        ? 0.0
        : points.fold<int>(0, (a, p) => a + p.amount.minor) /
            points.length /
            100;

    // Label density adapts to the number of bars so labels never collide.
    final labelEvery = points.length > 24 ? 5 : (points.length > 14 ? 3 : 2);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxY,
        minY: 0,
        groupsSpace: 2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => palette.cardElevated,
            tooltipBorder: BorderSide(color: palette.hairline),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= points.length) return null;
              final point = points[groupIndex];
              return BarTooltipItem(
                '${point.date.day} ${_monthShort(point.date)}\n',
                theme.textTheme.labelSmall!
                    .copyWith(color: palette.textTertiary),
                children: [
                  TextSpan(
                    text: formatter.format(point.amount),
                    style: theme.textTheme.titleSmall!
                        .copyWith(color: palette.expense),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: maxY / 3,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > maxY) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: Gap.sm),
                  child: Text(
                    formatter.compact(Money((value * 100).round())),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: palette.textTertiary),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final isLast = index == points.length - 1;
                if (index % labelEvery != 0 && !isLast) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: Gap.sm),
                  child: Text(
                    '${points[index].date.day}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: palette.textTertiary),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (value) => FlLine(
            color: palette.hairline,
            strokeWidth: 1,
            dashArray: const [4, 6],
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: average <= 0
            ? const ExtraLinesData()
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: average,
                    color: palette.savings.withValues(alpha: 0.55),
                    strokeWidth: 1.2,
                    dashArray: const [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: Gap.xs, bottom: 2),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: palette.savings),
                      labelResolver: (_) => 'avg',
                    ),
                  ),
                ],
              ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].amount.minor / 100,
                  width: _barWidth(points.length),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  color: points[i].amount.isZero
                      ? palette.hairline
                      : palette.expense,
                  gradient: points[i].amount.isZero
                      ? null
                      : LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            palette.expense.withValues(alpha: 0.55),
                            palette.expense,
                          ],
                        ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: palette.hairline.withValues(alpha: 0.32),
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: Motion.chart,
      curve: Motion.emphasized,
    );
  }

  static double _barWidth(int count) {
    if (count <= 0) return 10;
    if (count > 28) return 6.5;
    if (count > 20) return 8;
    if (count > 10) return 12;
    return 18;
  }

  static String _monthShort(DateTime date) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][date.month - 1];
}
