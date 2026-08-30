import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/utils/date_range.dart';
import '../core/utils/money.dart';
import '../models/analytics.dart';
import '../services/finance_calculator.dart';
import 'analytics_providers.dart';
import 'core_providers.dart';
import 'transaction_providers.dart';

/// Anchor of the financial month a budget belongs to.
typedef BudgetPeriod = ({int year, int month});

/// Which month the Budgets screen is showing.
class BudgetPeriodController extends Notifier<BudgetPeriod> {
  @override
  BudgetPeriod build() {
    return ref.watch(calendarProvider).periodKey(ref.watch(nowProvider));
  }

  void set(BudgetPeriod period) => state = period;

  void shift(int months) {
    final anchor = DateTime(state.year, state.month + months);
    state = (year: anchor.year, month: anchor.month);
  }
}

final budgetPeriodProvider =
    NotifierProvider<BudgetPeriodController, BudgetPeriod>(
        BudgetPeriodController.new);

final budgetPeriodRangeProvider = Provider<DateRange>((ref) {
  final period = ref.watch(budgetPeriodProvider);
  return ref.watch(calendarProvider).monthOf(period.year, period.month);
});

final budgetsForPeriodProvider =
    StreamProvider.family<List<BudgetRow>, BudgetPeriod>((ref, period) {
  return ref
      .watch(budgetRepositoryProvider)
      .watchForPeriod(period.year, period.month);
});

final spendByCategoryProvider =
    StreamProvider.family<Map<int?, Money>, DateRange>((ref, range) {
  return ref.watch(transactionRepositoryProvider).watchSpendByCategory(range);
});

/// Budgets for [period] joined with actual spending.
final budgetStatusesProvider =
    Provider.family<AsyncValue<List<BudgetStatus>>, BudgetPeriod>(
        (ref, period) {
  final calendar = ref.watch(calendarProvider);
  final range = calendar.monthOf(period.year, period.month);
  final settings = ref.watch(settingsProvider);

  final budgets = ref.watch(budgetsForPeriodProvider(period));
  final spend = ref.watch(spendByCategoryProvider(range));
  final totals = ref.watch(periodTotalsProvider(range));
  final categories = ref.watch(allCategoriesProvider);

  return combineAsync<List<BudgetStatus>>(
    [budgets, spend, totals, categories],
    () => FinanceCalculator.buildBudgetStatuses(
      budgets: budgets.requireValue,
      categoriesById: {
        for (final category in categories.requireValue) category.id: category,
      },
      spendByCategory: spend.requireValue,
      totalExpense: totals.requireValue.expense,
      range: range,
      warningThreshold: settings.budgetWarningThreshold,
      criticalThreshold: settings.budgetCriticalThreshold,
    ),
  );
});

/// Budget statuses for the month currently selected on the Budgets screen.
final selectedBudgetStatusesProvider =
    Provider<AsyncValue<List<BudgetStatus>>>((ref) {
  return ref.watch(budgetStatusesProvider(ref.watch(budgetPeriodProvider)));
});

/// Budget statuses for the month the user is actually living in - used by the
/// dashboard and by insight generation regardless of screen navigation.
final currentBudgetStatusesProvider =
    Provider<AsyncValue<List<BudgetStatus>>>((ref) {
  final period = ref.watch(calendarProvider).periodKey(ref.watch(nowProvider));
  return ref.watch(budgetStatusesProvider(period));
});

/// Budgets that need the user's attention right now.
final budgetAlertsProvider = Provider<List<BudgetStatus>>((ref) {
  final statuses = ref.watch(currentBudgetStatusesProvider).valueOrNull;
  if (statuses == null) return const [];
  return statuses
      .where((status) =>
          status.health == BudgetHealth.warning ||
          status.health == BudgetHealth.critical ||
          status.health == BudgetHealth.exceeded)
      .toList(growable: false);
});

/// Writes, wrapped so screens get a single object to call.
class BudgetActions {
  const BudgetActions(this._ref);

  final Ref _ref;

  Future<void> upsert({
    required int? categoryId,
    required int year,
    required int month,
    required Money amount,
  }) =>
      _ref.read(budgetRepositoryProvider).upsert(
            categoryId: categoryId,
            year: year,
            month: month,
            amount: amount,
          );

  Future<void> delete(int id) => _ref.read(budgetRepositoryProvider).delete(id);

  Future<int> copyFromPreviousMonth(BudgetPeriod period) {
    final previous = DateTime(period.year, period.month - 1);
    return _ref.read(budgetRepositoryProvider).copyPeriod(
          fromYear: previous.year,
          fromMonth: previous.month,
          toYear: period.year,
          toMonth: period.month,
        );
  }
}

final budgetActionsProvider =
    Provider<BudgetActions>((ref) => BudgetActions(ref));
