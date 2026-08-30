import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/money.dart';
import '../../models/analytics.dart';
import '../../models/enums.dart';
import '../../providers/analytics_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charts/category_donut_chart.dart';
import '../../widgets/charts/chart_card.dart';
import '../../widgets/charts/daily_expense_chart.dart';
import '../../widgets/charts/monthly_comparison_chart.dart';
import '../../widgets/states.dart';
import '../dashboard/widgets/insights_panel.dart';

enum _CategoryWindow { thisMonth, lastMonth, thisYear, custom }

/// Deep-dive analytics: yearly trends, category breakdowns and the numbers
/// behind the dashboard's headlines - all read from the local database.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  late int _year = DateTime.now().year;
  DateTime _dailyMonthAnchor = DateTime.now();
  _CategoryWindow _categoryWindow = _CategoryWindow.thisMonth;
  DateRange? _customCategoryRange;
  bool _showIncome = true;
  bool _showExpense = true;
  bool _showSavings = true;

  @override
  Widget build(BuildContext context) {
    final formatter = ref.watch(moneyFormatterProvider);
    final calendar = ref.watch(calendarProvider);
    final years = ref.watch(availableYearsProvider).valueOrNull ?? [_year];
    final yearRange = calendar.year(_year);
    final summary = ref.watch(analyticsSummaryProvider(yearRange));
    final dailyRange = calendar.month(_dailyMonthAnchor);
    final dailySeries = ref.watch(dailySeriesProvider(dailyRange));
    final categoryRange = _resolveCategoryRange(calendar);
    final categoryTotals = ref.watch(
      categoryTotalsProvider(
          (range: categoryRange, type: TransactionType.expense)),
    );
    final insights = ref.watch(insightsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.md),
            child: Center(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: years.contains(_year) ? _year : years.first,
                  items: years
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _year = value);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Gap.lg, Gap.md, Gap.lg, Gap.navClearance),
        children: [
          // Monthly comparison ------------------------------------------------
          ChartCard(
            title: 'Income vs expenses vs savings',
            subtitle: '$_year',
            height: 220,
            legend: ChartLegend(items: [
              _LegendToggle(
                label: 'Income',
                color: context.finance.income,
                value: _showIncome,
                onChanged: (v) => setState(() => _showIncome = v),
              ),
              _LegendToggle(
                label: 'Expenses',
                color: context.finance.expense,
                value: _showExpense,
                onChanged: (v) => setState(() => _showExpense = v),
              ),
              _LegendToggle(
                label: 'Savings',
                color: context.finance.savings,
                value: _showSavings,
                onChanged: (v) => setState(() => _showSavings = v),
              ),
            ]),
            child: AsyncView<List<MonthlyPoint>>(
              value: ref.watch(monthlySeriesProvider(_year)),
              builder: (context, points) {
                final hasData = points.any((p) => !p.isEmpty);
                if (!hasData) {
                  return ChartEmpty(
                    message: 'No activity recorded in $_year yet.',
                  );
                }
                return MonthlyComparisonChart(
                  points: points,
                  formatter: formatter,
                  showIncome: _showIncome,
                  showExpense: _showExpense,
                  showSavings: _showSavings,
                );
              },
            ),
          ),
          const SizedBox(height: Gap.xl),

          // Stat grid -----------------------------------------------------
          AsyncView<AnalyticsSummary>(
            value: summary,
            loading: const LoadingCard(height: 220),
            builder: (context, data) => _StatSections(
              summary: data,
              formatter: formatter,
            ),
          ),
          const SizedBox(height: Gap.xl),

          // Daily spending --------------------------------------------------
          ChartCard(
            title: 'Daily spending',
            subtitle: calendar.monthLabel(dailyRange.start),
            height: 190,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _dailyMonthAnchor =
                        calendar.previousMonth(_dailyMonthAnchor).start;
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _dailyMonthAnchor =
                        calendar.nextMonth(_dailyMonthAnchor).start;
                  }),
                ),
              ],
            ),
            child: AsyncView<List<DailyPoint>>(
              value: dailySeries,
              builder: (context, points) {
                final hasData = points.any((p) => !p.amount.isZero);
                if (!hasData) {
                  return const ChartEmpty(
                    message: 'No spending recorded this month.',
                  );
                }
                return DailyExpenseChart(points: points, formatter: formatter);
              },
            ),
          ),
          const SizedBox(height: Gap.xl),

          // Category breakdown ------------------------------------------------
          SectionHeader(
            title: 'Where your money went',
            action: _CategoryWindowMenu(
              value: _categoryWindow,
              onChanged: (value) async {
                if (value == _CategoryWindow.custom) {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 10),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked == null) return;
                  setState(() {
                    _categoryWindow = value;
                    _customCategoryRange = DateRange(
                      start: DateTime(
                          picked.start.year, picked.start.month, picked.start.day),
                      end: DateTime(
                          picked.end.year, picked.end.month, picked.end.day + 1),
                      label: 'Custom range',
                    );
                  });
                } else {
                  setState(() => _categoryWindow = value);
                }
              },
            ),
          ),
          AsyncView<List<CategoryTotal>>(
            value: categoryTotals,
            loading: const LoadingCard(height: 200),
            builder: (context, data) {
              if (data.isEmpty) {
                return const EmptyState(
                  icon: Icons.donut_large_rounded,
                  title: 'Nothing to show',
                  message:
                      'Once you record some expenses for this period, your '
                      'category breakdown will appear here.',
                  compact: true,
                );
              }
              final total = Money.sum(data.map((e) => e.total));
              return AppCard(
                child: Column(
                  children: [
                    SizedBox(
                      height: 190,
                      child: CategoryDonutChart(
                        categories: data,
                        formatter: formatter,
                        total: total,
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    CategoryBreakdownList(categories: data, formatter: formatter),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: Gap.xl),

          // Insights ------------------------------------------------------
          const SectionHeader(
            title: 'Insights',
            subtitle: 'Generated from your own records',
          ),
          AsyncView<List<Insight>>(
            value: insights,
            loading: const LoadingCard(height: 90, lines: 2),
            builder: (context, data) => InsightsPanel(insights: data),
          ),
        ],
      ),
    );
  }

  DateRange _resolveCategoryRange(FinancialCalendar calendar) {
    final now = DateTime.now();
    return switch (_categoryWindow) {
      _CategoryWindow.thisMonth => calendar.month(now),
      _CategoryWindow.lastMonth => calendar.previousMonth(now),
      _CategoryWindow.thisYear => calendar.yearOfDate(now),
      _CategoryWindow.custom =>
        _customCategoryRange ?? calendar.month(now),
    };
  }
}

class _LegendToggle extends StatelessWidget {
  const _LegendToggle({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(Corners.pill),
      child: Opacity(
        opacity: value ? 1 : 0.4,
        child: LegendDot(color: color, label: label),
      ),
    );
  }
}

class _CategoryWindowMenu extends StatelessWidget {
  const _CategoryWindowMenu({required this.value, required this.onChanged});

  final _CategoryWindow value;
  final ValueChanged<_CategoryWindow> onChanged;

  static const _labels = <_CategoryWindow, String>{
    _CategoryWindow.thisMonth: 'This month',
    _CategoryWindow.lastMonth: 'Last month',
    _CategoryWindow.thisYear: 'This year',
    _CategoryWindow.custom: 'Custom range',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CategoryWindow>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => _labels.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      child: Chip(
        label: Text(_labels[value]!),
        avatar: const Icon(Icons.tune_rounded, size: 16),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _StatSections extends StatelessWidget {
  const _StatSections({required this.summary, required this.formatter});

  final AnalyticsSummary summary;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatGroup(
          title: 'Income',
          color: palette.income,
          stats: [
            _Stat('Total', formatter.format(summary.totals.income, showDecimals: false)),
            _Stat('Average / month',
                formatter.format(summary.averageMonthlyIncome, showDecimals: false)),
            _Stat(
              'Highest month',
              summary.highestIncomeMonth == null
                  ? '-'
                  : '${summary.highestIncomeMonth!.label} · '
                      '${formatter.compact(summary.highestIncomeMonth!.income)}',
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        _StatGroup(
          title: 'Expenses',
          color: palette.expense,
          stats: [
            _Stat('Total', formatter.format(summary.totals.expense, showDecimals: false)),
            _Stat('Average / month',
                formatter.format(summary.averageMonthlyExpense, showDecimals: false)),
            _Stat('Average / day',
                formatter.format(summary.averageDailyExpense, showDecimals: false)),
            _Stat(
              'Highest month',
              summary.highestExpenseMonth == null
                  ? '-'
                  : '${summary.highestExpenseMonth!.label} · '
                      '${formatter.compact(summary.highestExpenseMonth!.expense)}',
            ),
            _Stat(
              'Top category',
              summary.topExpenseCategory == null
                  ? '-'
                  : '${summary.topExpenseCategory!.name} · '
                      '${formatter.compact(summary.topExpenseCategory!.total)}',
            ),
            _Stat(
              'Busiest weekday',
              summary.highestSpendingWeekday == null
                  ? '-'
                  : '${summary.highestSpendingWeekday!.weekday} · '
                      '${formatter.compact(summary.highestSpendingWeekday!.amount)}',
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        _StatGroup(
          title: 'Savings',
          color: palette.savings,
          stats: [
            _Stat('Total', formatter.format(summary.totals.savings, showDecimals: false)),
            _Stat('Average / month',
                formatter.format(summary.averageMonthlySavings, showDecimals: false)),
            _Stat(
              'Savings rate',
              summary.totals.savingsRate == null
                  ? '-'
                  : '${summary.totals.savingsRate!.clamp(0, 999).toStringAsFixed(0)}% of income',
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
}

class _StatGroup extends StatelessWidget {
  const _StatGroup({
    required this.title,
    required this.color,
    required this.stats,
  });

  final String title;
  final Color color;
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: Gap.sm),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.xl,
            runSpacing: Gap.md,
            children: [
              for (final stat in stats)
                SizedBox(
                  width: 140,
                  child: StatPill(label: stat.label, value: stat.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
