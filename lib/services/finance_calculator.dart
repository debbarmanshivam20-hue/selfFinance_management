import '../core/database/app_database.dart';
import '../core/utils/date_range.dart';
import '../core/utils/money.dart';
import '../models/analytics.dart';

/// Pure derivations over already-aggregated data.
///
/// Nothing here touches the database or Flutter, which is what makes the
/// financial rules straightforward to unit test. Widgets call into this layer
/// rather than computing money inside `build()`.
class FinanceCalculator {
  FinanceCalculator._();

  /// Percentage change from [previous] to [current].
  ///
  /// Returns `null` when there is no previous figure to compare against -
  /// "expenses are up 100%" from a zero baseline is a meaningless statistic,
  /// and the UI shows nothing rather than inventing one.
  static double? percentChange(Money previous, Money current) {
    if (previous.minor == 0) return null;
    return (current.minor - previous.minor) * 100 / previous.minor;
  }

  /// Mean expense per day across [range].
  static Money averageDailyExpense(Money totalExpense, DateRange range) {
    final days = range.dayCount;
    if (days <= 0) return Money.zero;
    return Money(totalExpense.minor ~/ days);
  }

  /// Mean per month, using only months that contain activity so a mid-year
  /// start does not halve the user's real average.
  static Money averagePerActiveMonth(Money total, int activeMonths) {
    if (activeMonths <= 0) return Money.zero;
    return Money(total.minor ~/ activeMonths);
  }

  static int activeMonthCount(List<MonthlyPoint> series) =>
      series.where((point) => !point.isEmpty).length;

  static MonthlyPoint? highestBy(
    List<MonthlyPoint> series,
    Money Function(MonthlyPoint) selector,
  ) {
    MonthlyPoint? best;
    for (final point in series) {
      if (selector(point).isZero) continue;
      if (best == null || selector(point) > selector(best)) best = point;
    }
    return best;
  }

  static DailyPoint? highestSpendingDay(List<DailyPoint> series) {
    DailyPoint? best;
    for (final point in series) {
      if (point.amount.isZero) continue;
      if (best == null || point.amount > best.amount) best = point;
    }
    return best;
  }

  /// Which weekday the user spends most on, totalled across [series].
  static ({String weekday, Money amount})? busiestWeekday(
    List<DailyPoint> series,
  ) {
    final totals = <int, int>{};
    for (final point in series) {
      if (point.amount.isZero) continue;
      totals[point.date.weekday] =
          (totals[point.date.weekday] ?? 0) + point.amount.minor;
    }
    if (totals.isEmpty) return null;

    var bestDay = totals.keys.first;
    for (final entry in totals.entries) {
      if (entry.value > totals[bestDay]!) bestDay = entry.key;
    }
    // 2024-01-01 was a Monday, so adding (weekday - 1) days lands on the right
    // day of the week for formatting.
    final sample = DateTime(2024, 1, 1).add(Duration(days: bestDay - 1));
    return (
      weekday: DateLabels.weekday.format(sample),
      amount: Money(totals[bestDay]!),
    );
  }

  /// Assembles the Analytics screen's numbers from pre-aggregated inputs.
  static AnalyticsSummary summarise({
    required DateRange range,
    required PeriodTotals totals,
    required List<MonthlyPoint> monthlySeries,
    required List<DailyPoint> dailyExpenses,
    required List<CategoryTotal> expenseCategories,
  }) {
    final activeMonths = activeMonthCount(monthlySeries);
    return AnalyticsSummary(
      range: range,
      totals: totals,
      monthlySeries: monthlySeries,
      highestIncomeMonth: highestBy(monthlySeries, (p) => p.income),
      highestExpenseMonth: highestBy(monthlySeries, (p) => p.expense),
      averageMonthlyIncome: averagePerActiveMonth(totals.income, activeMonths),
      averageMonthlyExpense: averagePerActiveMonth(totals.expense, activeMonths),
      averageMonthlySavings: averagePerActiveMonth(totals.savings, activeMonths),
      averageDailyExpense: _averageDailyOverActiveRange(dailyExpenses, range),
      topExpenseCategory:
          expenseCategories.isEmpty ? null : expenseCategories.first,
      highestSpendingDay: highestSpendingDay(dailyExpenses),
      highestSpendingWeekday: busiestWeekday(dailyExpenses),
      activeMonthCount: activeMonths,
    );
  }

  /// Averages across elapsed days only: on the 5th of the month the user's
  /// "average daily spend" should divide by 5, not by 31.
  static Money _averageDailyOverActiveRange(
    List<DailyPoint> series,
    DateRange range,
  ) {
    if (series.isEmpty) return Money.zero;
    final now = DateTime.now();
    final effectiveEnd = range.end.isAfter(now) ? now : range.end;
    var days = effectiveEnd.difference(range.start).inDays + 1;
    if (days <= 0) days = 1;
    if (days > series.length) days = series.length;
    final total = Money.sum(series.map((point) => point.amount));
    return Money(total.minor ~/ days);
  }

  /// Joins budgets with what was actually spent against them.
  static List<BudgetStatus> buildBudgetStatuses({
    required List<BudgetRow> budgets,
    required Map<int, CategoryRow> categoriesById,
    required Map<int?, Money> spendByCategory,
    required Money totalExpense,
    required DateRange range,
    required double warningThreshold,
    required double criticalThreshold,
  }) {
    final statuses = budgets.map((budget) {
      final spent = budget.categoryId == null
          ? totalExpense
          : (spendByCategory[budget.categoryId] ?? Money.zero);
      return BudgetStatus(
        budget: budget,
        category: budget.categoryId == null
            ? null
            : categoriesById[budget.categoryId],
        spent: spent,
        range: range,
        warningThreshold: warningThreshold,
        criticalThreshold: criticalThreshold,
      );
    }).toList();

    // Overall budget first, then the most at-risk category budgets.
    statuses.sort((a, b) {
      if (a.category == null) return -1;
      if (b.category == null) return 1;
      return b.percentUsed.compareTo(a.percentUsed);
    });
    return statuses;
  }

  static List<GoalProgress> buildGoalProgress({
    required List<SavingsGoalRow> goals,
    required Map<int, ({Money total, int count, DateTime? last})> contributions,
  }) {
    return goals.map((goal) {
      final entry = contributions[goal.id];
      return GoalProgress(
        goal: goal,
        contributed: entry?.total ?? Money.zero,
        contributionCount: entry?.count ?? 0,
        lastContributionAt: entry?.last,
      );
    }).toList(growable: false);
  }
}
