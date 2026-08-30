import 'package:flutter/foundation.dart';

import '../core/database/app_database.dart';
import '../core/utils/date_range.dart';
import '../core/utils/money.dart';

/// Money totals for one window of time.
///
/// Transfers are deliberately *not* part of income, expense or savings: moving
/// ₹5,000 from Bank to Cash changes no total, it only moves an account
/// balance. [transferVolume] is tracked separately for the accounts view.
@immutable
class PeriodTotals {
  const PeriodTotals({
    required this.range,
    required this.income,
    required this.expense,
    required this.savings,
    required this.transferVolume,
    required this.transactionCount,
  });

  final DateRange range;
  final Money income;
  final Money expense;
  final Money savings;
  final Money transferVolume;
  final int transactionCount;

  static PeriodTotals empty(DateRange range) => PeriodTotals(
        range: range,
        income: Money.zero,
        expense: Money.zero,
        savings: Money.zero,
        transferVolume: Money.zero,
        transactionCount: 0,
      );

  /// Money left to spend: what came in, minus what went out, minus what was
  /// deliberately set aside.
  Money get available => income - expense - savings;

  /// Everything the user still owns - savings are their money too.
  Money get netWorth => income - expense;

  /// Share of income that was put into savings, 0-100. `null` when there is no
  /// income in the window (dividing by zero would be a fabricated statistic).
  double? get savingsRate => savings.percentOf(income);

  /// Share of income that was spent, 0-100.
  double? get expenseRate => expense.percentOf(income);

  bool get isEmpty => transactionCount == 0;

  PeriodTotals operator +(PeriodTotals other) => PeriodTotals(
        range: range,
        income: income + other.income,
        expense: expense + other.expense,
        savings: savings + other.savings,
        transferVolume: transferVolume + other.transferVolume,
        transactionCount: transactionCount + other.transactionCount,
      );
}

/// One slice of the category breakdown.
@immutable
class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.total,
    required this.transactionCount,
    required this.share,
  });

  final int? categoryId;
  final String name;
  final String iconKey;
  final int colorValue;
  final Money total;
  final int transactionCount;

  /// Percentage of the period's total, 0-100.
  final double share;
}

/// A single bar in the daily chart.
@immutable
class DailyPoint {
  const DailyPoint({required this.date, required this.amount});

  final DateTime date;
  final Money amount;
}

/// A single x-position in the monthly comparison chart.
@immutable
class MonthlyPoint {
  const MonthlyPoint({
    required this.anchor,
    required this.label,
    required this.income,
    required this.expense,
    required this.savings,
  });

  /// First day of the financial month this point covers.
  final DateTime anchor;
  final String label;
  final Money income;
  final Money expense;
  final Money savings;

  bool get isEmpty => income.isZero && expense.isZero && savings.isZero;
}

/// Running balance of one payment method / account.
@immutable
class AccountBalance {
  const AccountBalance({required this.account, required this.balance});

  final PaymentMethodRow account;
  final Money balance;
}

enum BudgetHealth {
  normal,
  warning,
  critical,
  exceeded;

  String get label => switch (this) {
        BudgetHealth.normal => 'On track',
        BudgetHealth.warning => 'Watch',
        BudgetHealth.critical => 'Almost gone',
        BudgetHealth.exceeded => 'Over budget',
      };
}

/// A budget joined with what has actually been spent against it.
@immutable
class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.category,
    required this.spent,
    required this.range,
    required this.warningThreshold,
    required this.criticalThreshold,
  });

  final BudgetRow budget;

  /// `null` for an overall (all-categories) budget.
  final CategoryRow? category;
  final Money spent;
  final DateRange range;
  final double warningThreshold;
  final double criticalThreshold;

  String get name => category?.name ?? 'Overall budget';
  Money get limit => Money(budget.amountMinor);
  Money get remaining => limit - spent;
  bool get isOverspent => spent > limit;

  /// 0-100+, uncapped so the UI can say "142% used".
  double get percentUsed {
    if (limit.minor <= 0) return 0;
    return spent.minor * 100 / limit.minor;
  }

  /// Clamped for progress bars.
  double get progress => (percentUsed / 100).clamp(0.0, 1.0);

  BudgetHealth get health {
    final used = percentUsed;
    if (used > 100) return BudgetHealth.exceeded;
    if (used >= criticalThreshold) return BudgetHealth.critical;
    if (used >= warningThreshold) return BudgetHealth.warning;
    return BudgetHealth.normal;
  }

  /// Suggested daily spend to finish the period on budget, or `null` when the
  /// budget is already spent or the period is over.
  Money? get safeDailySpend {
    final now = DateTime.now();
    if (remaining.minor <= 0) return null;
    if (!range.contains(now)) return null;
    final daysLeft = range.end.difference(now).inDays + 1;
    if (daysLeft <= 0) return null;
    return Money(remaining.minor ~/ daysLeft);
  }
}

/// A savings goal joined with the savings transactions earmarked for it.
@immutable
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.contributed,
    required this.contributionCount,
    required this.lastContributionAt,
  });

  final SavingsGoalRow goal;

  /// Sum of savings transactions tagged with this goal.
  final Money contributed;
  final int contributionCount;
  final DateTime? lastContributionAt;

  String get name => goal.name;
  Money get target => Money(goal.targetMinor);

  /// Opening balance plus everything contributed since.
  Money get saved => Money(goal.openingMinor) + contributed;
  Money get remaining {
    final left = target - saved;
    return left.isNegative ? Money.zero : left;
  }

  bool get isComplete => saved >= target;

  double get percent {
    if (target.minor <= 0) return 0;
    return (saved.minor * 100 / target.minor);
  }

  double get progress => (percent / 100).clamp(0.0, 1.0);

  int? get daysRemaining {
    final due = goal.targetDate;
    if (due == null) return null;
    final today = DateTime.now();
    return DateTime(due.year, due.month, due.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  /// How much needs to be saved each month to hit the target date.
  Money? get requiredMonthlyContribution {
    final days = daysRemaining;
    if (days == null || days <= 0 || isComplete) return null;
    final months = (days / 30).ceil();
    if (months <= 0) return null;
    return Money(remaining.minor ~/ months);
  }
}

enum InsightTone { positive, negative, neutral, warning }

/// One generated statement on the Insights panel.
///
/// Every insight is derived from stored rows; when there is not enough data
/// the services return an empty list and the UI shows a prompt instead of an
/// invented number.
@immutable
class Insight {
  const Insight({
    required this.id,
    required this.message,
    required this.tone,
    required this.iconKey,
    this.detail,
  });

  final String id;
  final String message;
  final String? detail;
  final InsightTone tone;
  final String iconKey;
}

/// The aggregate numbers behind the Analytics screen.
@immutable
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.range,
    required this.totals,
    required this.monthlySeries,
    required this.highestIncomeMonth,
    required this.highestExpenseMonth,
    required this.averageMonthlyIncome,
    required this.averageMonthlyExpense,
    required this.averageMonthlySavings,
    required this.averageDailyExpense,
    required this.topExpenseCategory,
    required this.highestSpendingDay,
    required this.highestSpendingWeekday,
    required this.activeMonthCount,
  });

  final DateRange range;
  final PeriodTotals totals;
  final List<MonthlyPoint> monthlySeries;
  final MonthlyPoint? highestIncomeMonth;
  final MonthlyPoint? highestExpenseMonth;
  final Money averageMonthlyIncome;
  final Money averageMonthlyExpense;
  final Money averageMonthlySavings;
  final Money averageDailyExpense;
  final CategoryTotal? topExpenseCategory;
  final DailyPoint? highestSpendingDay;

  /// e.g. ("Saturday", ₹12,400) - the weekday the user spends most on.
  final ({String weekday, Money amount})? highestSpendingWeekday;

  /// Months in the window that actually contain transactions; used as the
  /// divisor for averages so a mid-year start does not deflate them.
  final int activeMonthCount;
}
