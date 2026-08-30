import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_range.dart';
import '../models/analytics.dart';
import '../models/enums.dart';
import '../services/finance_calculator.dart';
import 'budget_providers.dart';
import 'core_providers.dart';
import 'goal_providers.dart';

/// Totals for an arbitrary window.
final periodTotalsProvider =
    StreamProvider.family<PeriodTotals, DateRange>((ref, range) {
  return ref.watch(transactionRepositoryProvider).watchTotals(range);
});

/// Totals across every transaction ever recorded.
final allTimeTotalsProvider = StreamProvider<PeriodTotals>((ref) {
  return ref.watch(transactionRepositoryProvider).watchTotals(null);
});

final todayTotalsProvider = StreamProvider<PeriodTotals>((ref) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTotals(ref.watch(todayRangeProvider));
});

final weekTotalsProvider = StreamProvider<PeriodTotals>((ref) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTotals(ref.watch(thisWeekRangeProvider));
});

final monthTotalsProvider = StreamProvider<PeriodTotals>((ref) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTotals(ref.watch(thisMonthRangeProvider));
});

final lastMonthTotalsProvider = StreamProvider<PeriodTotals>((ref) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTotals(ref.watch(lastMonthRangeProvider));
});

final yearTotalsProvider = StreamProvider<PeriodTotals>((ref) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTotals(ref.watch(thisYearRangeProvider));
});

/// Daily bars for a window. Days without spending are present as zero.
final dailySeriesProvider =
    StreamProvider.family<List<DailyPoint>, DateRange>((ref, range) {
  return ref.watch(transactionRepositoryProvider).watchDailySeries(range);
});

/// Income / expense / savings across the 12 months of a year.
final monthlySeriesProvider =
    StreamProvider.family<List<MonthlyPoint>, int>((ref, year) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchMonthlySeries(year, ref.watch(calendarProvider));
});

/// Key for a category breakdown query.
typedef CategoryBreakdownQuery = ({DateRange? range, TransactionType type});

final categoryTotalsProvider = StreamProvider.family<List<CategoryTotal>,
    CategoryBreakdownQuery>((ref, query) {
  return ref.watch(transactionRepositoryProvider).watchCategoryTotals(
        range: query.range,
        type: query.type,
      );
});

/// The full Analytics screen model for a window.
final analyticsSummaryProvider =
    Provider.family<AsyncValue<AnalyticsSummary>, DateRange>((ref, range) {
  final totals = ref.watch(periodTotalsProvider(range));
  final daily = ref.watch(dailySeriesProvider(range));
  final monthly = ref.watch(monthlySeriesProvider(range.start.year));
  final categories = ref.watch(
    categoryTotalsProvider((range: range, type: TransactionType.expense)),
  );

  return combineAsync<AnalyticsSummary>(
    [totals, daily, monthly, categories],
    () => FinanceCalculator.summarise(
      range: range,
      totals: totals.requireValue,
      monthlySeries: monthly.requireValue,
      dailyExpenses: daily.requireValue,
      expenseCategories: categories.requireValue,
    ),
  );
});

/// Month-over-month change in spending, as a percentage.
final expenseTrendProvider = Provider<AsyncValue<double?>>((ref) {
  final current = ref.watch(monthTotalsProvider);
  final previous = ref.watch(lastMonthTotalsProvider);
  return combineAsync<double?>(
    [current, previous],
    () => FinanceCalculator.percentChange(
      previous.requireValue.expense,
      current.requireValue.expense,
    ),
  );
});

/// Generated insights for the current month.
final insightsProvider = Provider<AsyncValue<List<Insight>>>((ref) {
  final thisMonth = ref.watch(thisMonthRangeProvider);
  final lastMonth = ref.watch(lastMonthRangeProvider);

  final current = ref.watch(monthTotalsProvider);
  final previous = ref.watch(lastMonthTotalsProvider);
  final currentCategories = ref.watch(
    categoryTotalsProvider((range: thisMonth, type: TransactionType.expense)),
  );
  final previousCategories = ref.watch(
    categoryTotalsProvider((range: lastMonth, type: TransactionType.expense)),
  );
  final daily = ref.watch(dailySeriesProvider(thisMonth));
  final budgets = ref.watch(currentBudgetStatusesProvider);
  final goals = ref.watch(goalProgressProvider);

  return combineAsync<List<Insight>>(
    [current, previous, currentCategories, previousCategories, daily, budgets, goals],
    () => ref.read(insightsServiceProvider).generate(
          currentMonth: current.requireValue,
          previousMonth: previous.requireValue,
          currentCategories: currentCategories.requireValue,
          previousCategories: previousCategories.requireValue,
          dailyExpenses: daily.requireValue,
          budgets: budgets.requireValue,
          goals: goals.requireValue,
          formatter: ref.watch(moneyFormatterProvider),
        ),
  );
});
