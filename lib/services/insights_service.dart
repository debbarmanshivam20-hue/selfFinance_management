import '../core/utils/date_range.dart';
import '../core/utils/money.dart';
import '../models/analytics.dart';
import 'finance_calculator.dart';

/// Turns stored data into short plain-English observations.
///
/// Every statement here is computed from rows the user actually entered. When
/// there is not enough history to say something true, the generator returns
/// fewer insights (or none) rather than filling the space with a guess.
class InsightsService {
  const InsightsService();

  /// Below this many transactions in the current month, percentage
  /// comparisons are noise rather than signal.
  static const int minimumTransactions = 3;

  List<Insight> generate({
    required PeriodTotals currentMonth,
    required PeriodTotals previousMonth,
    required List<CategoryTotal> currentCategories,
    required List<CategoryTotal> previousCategories,
    required List<DailyPoint> dailyExpenses,
    required List<BudgetStatus> budgets,
    required List<GoalProgress> goals,
    required MoneyFormatter formatter,
  }) {
    if (currentMonth.transactionCount < minimumTransactions) {
      return const <Insight>[];
    }

    final insights = <Insight>[];

    _addSpendTrend(insights, currentMonth, previousMonth, formatter);
    _addTopCategory(insights, currentCategories, currentMonth, formatter);
    _addSavingsRate(insights, currentMonth, previousMonth);
    _addBusiestDay(insights, dailyExpenses, formatter);
    _addCategorySpike(insights, currentCategories, previousCategories, formatter);
    _addBudgetWarning(insights, budgets, formatter);
    _addGoalNudge(insights, goals, formatter);
    _addIncomeTrend(insights, currentMonth, previousMonth);

    return insights;
  }

  void _addSpendTrend(
    List<Insight> out,
    PeriodTotals current,
    PeriodTotals previous,
    MoneyFormatter formatter,
  ) {
    final change = FinanceCalculator.percentChange(previous.expense, current.expense);
    if (change == null) return;
    // Sub-2% month-to-month drift is not worth a callout.
    if (change.abs() < 2) {
      out.add(const Insight(
        id: 'spend-flat',
        message: 'Your spending is holding steady against last month.',
        tone: InsightTone.neutral,
        iconKey: 'transfer',
      ));
      return;
    }

    final magnitude = change.abs().toStringAsFixed(0);
    final difference = (current.expense - previous.expense).abs;
    if (change > 0) {
      out.add(Insight(
        id: 'spend-up',
        message: 'Your expenses increased by $magnitude% compared with last month.',
        detail: '${formatter.format(difference)} more than last month.',
        tone: InsightTone.negative,
        iconKey: 'investment',
      ));
    } else {
      out.add(Insight(
        id: 'spend-down',
        message: 'You spent $magnitude% less this month than last month.',
        detail: '${formatter.format(difference)} saved versus last month.',
        tone: InsightTone.positive,
        iconKey: 'savings',
      ));
    }
  }

  void _addTopCategory(
    List<Insight> out,
    List<CategoryTotal> categories,
    PeriodTotals current,
    MoneyFormatter formatter,
  ) {
    if (categories.isEmpty) return;
    final top = categories.first;
    if (top.total.isZero) return;
    out.add(Insight(
      id: 'top-category',
      message: '${top.name} is your highest spending category this month.',
      detail:
          '${formatter.format(top.total)} · ${top.share.toStringAsFixed(0)}% of this month\'s spending.',
      tone: InsightTone.neutral,
      iconKey: top.iconKey,
    ));
  }

  void _addSavingsRate(
    List<Insight> out,
    PeriodTotals current,
    PeriodTotals previous,
  ) {
    final rate = current.savingsRate;
    if (rate == null) return;

    final rounded = rate.clamp(0, 999).toStringAsFixed(0);
    final previousRate = previous.savingsRate;

    String? trend;
    if (previousRate != null) {
      final delta = rate - previousRate;
      if (delta.abs() >= 1) {
        trend = delta > 0
            ? 'Up ${delta.toStringAsFixed(0)} points on last month.'
            : 'Down ${delta.abs().toStringAsFixed(0)} points on last month.';
      }
    }

    out.add(Insight(
      id: 'savings-rate',
      message: 'Your savings rate is $rounded% of your income.',
      detail: trend,
      tone: rate >= 20
          ? InsightTone.positive
          : (rate <= 5 ? InsightTone.warning : InsightTone.neutral),
      iconKey: 'piggy',
    ));
  }

  void _addBusiestDay(
    List<Insight> out,
    List<DailyPoint> daily,
    MoneyFormatter formatter,
  ) {
    final weekday = FinanceCalculator.busiestWeekday(daily);
    if (weekday == null) return;
    final peak = FinanceCalculator.highestSpendingDay(daily);
    out.add(Insight(
      id: 'busiest-day',
      message: 'Your highest spending day was ${weekday.weekday}.',
      detail: peak == null
          ? null
          : 'Biggest single day: ${DateLabels.medium.format(peak.date)} · ${formatter.format(peak.amount)}.',
      tone: InsightTone.neutral,
      iconKey: 'entertainment',
    ));
  }

  void _addCategorySpike(
    List<Insight> out,
    List<CategoryTotal> current,
    List<CategoryTotal> previous,
    MoneyFormatter formatter,
  ) {
    if (current.isEmpty || previous.isEmpty) return;
    final previousById = <int?, Money>{
      for (final entry in previous) entry.categoryId: entry.total,
    };

    CategoryTotal? spiked;
    double biggestJump = 0;
    for (final entry in current) {
      final before = previousById[entry.categoryId];
      if (before == null || before.isZero) continue;
      final change = FinanceCalculator.percentChange(before, entry.total);
      if (change == null || change < 30) continue;
      if (change > biggestJump) {
        biggestJump = change;
        spiked = entry;
      }
    }

    if (spiked == null) return;
    out.add(Insight(
      id: 'category-spike',
      message:
          '${spiked.name} spending is up ${biggestJump.toStringAsFixed(0)}% on last month.',
      detail: '${formatter.format(spiked.total)} so far this month.',
      tone: InsightTone.warning,
      iconKey: spiked.iconKey,
    ));
  }

  void _addBudgetWarning(
    List<Insight> out,
    List<BudgetStatus> budgets,
    MoneyFormatter formatter,
  ) {
    if (budgets.isEmpty) return;

    final exceeded = budgets.where((b) => b.isOverspent).toList();
    if (exceeded.isNotEmpty) {
      final worst = exceeded.first;
      out.add(Insight(
        id: 'budget-exceeded',
        message:
            'You are over your ${worst.name.toLowerCase()} budget by ${formatter.format(worst.spent - worst.limit)}.',
        detail: '${worst.percentUsed.toStringAsFixed(0)}% of the budget used.',
        tone: InsightTone.negative,
        iconKey: 'bills',
      ));
      return;
    }

    final atRisk = budgets
        .where((b) => b.health == BudgetHealth.critical ||
            b.health == BudgetHealth.warning)
        .toList();
    if (atRisk.isEmpty) return;
    final worst = atRisk.first;
    out.add(Insight(
      id: 'budget-warning',
      message:
          'You have used ${worst.percentUsed.toStringAsFixed(0)}% of your ${worst.name.toLowerCase()} budget.',
      detail: '${formatter.format(worst.remaining)} left for this month.',
      tone: InsightTone.warning,
      iconKey: 'bills',
    ));
  }

  void _addGoalNudge(
    List<Insight> out,
    List<GoalProgress> goals,
    MoneyFormatter formatter,
  ) {
    if (goals.isEmpty) return;

    final completed = goals.where((g) => g.isComplete).toList();
    if (completed.isNotEmpty) {
      out.add(Insight(
        id: 'goal-complete',
        message: 'You have reached your "${completed.first.name}" goal.',
        detail: '${formatter.format(completed.first.saved)} saved.',
        tone: InsightTone.positive,
        iconKey: 'goal',
      ));
      return;
    }

    final active = goals.where((g) => !g.isComplete).toList()
      ..sort((a, b) => b.percent.compareTo(a.percent));
    final leader = active.first;
    if (leader.percent < 1) return;

    final monthly = leader.requiredMonthlyContribution;
    out.add(Insight(
      id: 'goal-progress',
      message:
          '"${leader.name}" is ${leader.percent.toStringAsFixed(0)}% funded.',
      detail: monthly == null
          ? '${formatter.format(leader.remaining)} to go.'
          : 'Save ${formatter.format(monthly)} a month to hit the target date.',
      tone: InsightTone.neutral,
      iconKey: leader.goal.iconKey,
    ));
  }

  void _addIncomeTrend(
    List<Insight> out,
    PeriodTotals current,
    PeriodTotals previous,
  ) {
    final change = FinanceCalculator.percentChange(previous.income, current.income);
    if (change == null || change.abs() < 5) return;
    out.add(Insight(
      id: 'income-trend',
      message: change > 0
          ? 'Your income is up ${change.toStringAsFixed(0)}% on last month.'
          : 'Your income is down ${change.abs().toStringAsFixed(0)}% on last month.',
      tone: change > 0 ? InsightTone.positive : InsightTone.warning,
      iconKey: 'salary',
    ));
  }
}
