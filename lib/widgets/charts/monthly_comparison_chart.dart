import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/money.dart';
import '../../models/analytics.dart';

/// Income, expenses and savings across the twelve months of a year.
class MonthlyComparisonChart extends StatelessWidget {
  const MonthlyComparisonChart({
    super.key,
    required this.points,
    required this.formatter,
    this.showIncome = true,
    this.showExpense = true,
    this.showSavings = true,
  });

  final List<MonthlyPoint> points;
  final MoneyFormatter formatter;
  final bool showIncome;
  final bool showExpense;
  final bool showSavings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    var maxMinor = 0;
    for (final point in points) {
      if (showIncome && point.income.minor > maxMinor) {
        maxMinor = point.income.minor;
      }
      if (showExpense && point.expense.minor > maxMinor) {
        maxMinor = point.expense.minor;
      }
      if (showSavings && point.savings.minor > maxMinor) {
        maxMinor = point.savings.minor;
      }
    }
    final maxY = maxMinor == 0 ? 100.0 : (maxMinor / 100) * 1.2;

    List<FlSpot> spots(Money Function(MonthlyPoint) selector) => [
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), selector(points[i]).minor / 100),
        ];

    LineChartBarData line(
      List<FlSpot> data,
      Color color, {
      bool fill = false,
    }) {
      return LineChartBarData(
        spots: data,
        isCurved: true,
        curveSmoothness: 0.28,
        preventCurveOverShooting: true,
        color: color,
        barWidth: 2.6,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 2.6,
            color: color,
            strokeWidth: 1.6,
            strokeColor: palette.card,
          ),
        ),
        belowBarData: BarAreaData(
          show: fill,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => palette.cardElevated,
            tooltipBorder: BorderSide(color: palette.hairline),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
            maxContentWidth: 220,
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return <LineTooltipItem?>[];
              final index = touchedSpots.first.x.toInt();
              final label = (index >= 0 && index < points.length)
                  ? points[index].label
                  : '';
              return List<LineTooltipItem?>.generate(touchedSpots.length, (i) {
                final spot = touchedSpots[i];
                final color = spot.bar.color ?? palette.textPrimary;
                final name = _seriesName(color, palette);
                return LineTooltipItem(
                  i == 0 ? '$label\n' : '',
                  theme.textTheme.labelSmall!
                      .copyWith(color: palette.textTertiary),
                  children: [
                    TextSpan(
                      text:
                          '$name  ${formatter.format(Money((spot.y * 100).round()), showDecimals: false)}',
                      style: theme.textTheme.labelMedium!.copyWith(color: color),
                    ),
                  ],
                  textAlign: TextAlign.left,
                );
              });
            },
          ),
          getTouchedSpotIndicator: (barData, indexes) => indexes
              .map((index) => TouchedSpotIndicatorData(
                    FlLine(
                      color: palette.textTertiary.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: const [3, 3],
                    ),
                    FlDotData(
                      getDotPainter: (spot, percent, bar, i) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: bar.color ?? palette.textPrimary,
                        strokeWidth: 2,
                        strokeColor: palette.card,
                      ),
                    ),
                  ))
              .toList(),
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
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                // Every other month keeps 12 labels readable on a phone.
                if (points.length > 8 && index.isOdd) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: Gap.sm),
                  child: Text(
                    points[index].label,
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
        lineBarsData: [
          if (showIncome)
            line(spots((p) => p.income), palette.income, fill: true),
          if (showExpense) line(spots((p) => p.expense), palette.expense),
          if (showSavings) line(spots((p) => p.savings), palette.savings),
        ],
      ),
      duration: Motion.chart,
      curve: Motion.emphasized,
    );
  }

  String _seriesName(Color color, FinanceColors palette) {
    if (color == palette.income) return 'Income';
    if (color == palette.expense) return 'Expenses';
    if (color == palette.savings) return 'Savings';
    return '';
  }
}
