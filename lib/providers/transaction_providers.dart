import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/utils/date_range.dart';
import '../core/utils/money.dart';
import '../models/analytics.dart';
import '../models/enums.dart';
import '../models/transaction_draft.dart';
import '../models/transaction_filter.dart';
import '../models/transaction_view.dart';
import 'core_providers.dart';

/// The live filter behind the Transactions screen.
class TransactionFilterController extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter();

  void setTypes(Set<TransactionType> types) =>
      state = state.copyWith(types: types);

  void toggleType(TransactionType type) {
    final next = Set<TransactionType>.from(state.types);
    if (!next.remove(type)) next.add(type);
    state = state.copyWith(types: next);
  }

  void setPreset(DatePreset preset) => state = state.copyWith(
        preset: preset,
        clearCustomRange: preset != DatePreset.custom,
      );

  void setCustomRange(DateRange range) =>
      state = state.copyWith(preset: DatePreset.custom, customRange: range);

  void setQuery(String query) => state = state.copyWith(query: query);

  void setCategory(int? categoryId) => categoryId == null
      ? state = state.copyWith(clearCategory: true)
      : state = state.copyWith(categoryId: categoryId);

  void setPaymentMethod(int? methodId) => methodId == null
      ? state = state.copyWith(clearPaymentMethod: true)
      : state = state.copyWith(paymentMethodId: methodId);

  void setSort(TransactionSort sort) => state = state.copyWith(sort: sort);

  void clearFilters() => state = state.cleared();

  void reset() => state = const TransactionFilter();
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterController, TransactionFilter>(
        TransactionFilterController.new);

/// The transaction list for the current filter.
final filteredTransactionsProvider =
    StreamProvider.autoDispose<List<TransactionView>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final filter = ref.watch(transactionFilterProvider);
  final calendar = ref.watch(calendarProvider);
  return repository.watchFiltered(filter, calendar);
});

/// Totals for whatever the transaction list is currently showing.
final filteredTotalsProvider = Provider.autoDispose<PeriodTotals?>((ref) {
  final transactions = ref.watch(filteredTransactionsProvider).valueOrNull;
  if (transactions == null) return null;

  final calendar = ref.watch(calendarProvider);
  final filter = ref.watch(transactionFilterProvider);
  final range = filter.resolveRange(calendar) ??
      DateRange(start: DateTime(1970), end: DateTime(9999), label: 'All time');

  var income = 0;
  var expense = 0;
  var savings = 0;
  var transfer = 0;
  for (final item in transactions) {
    switch (item.type) {
      case TransactionType.income:
        income += item.row.amountMinor;
      case TransactionType.expense:
        expense += item.row.amountMinor;
      case TransactionType.savings:
        savings += item.row.amountMinor;
      case TransactionType.transfer:
        transfer += item.row.amountMinor;
    }
  }

  return PeriodTotals(
    range: range,
    income: Money(income),
    expense: Money(expense),
    savings: Money(savings),
    transferVolume: Money(transfer),
    transactionCount: transactions.length,
  );
});

final recentTransactionsProvider =
    StreamProvider<List<TransactionView>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchRecent(limit: 6);
});

final transactionCountProvider = StreamProvider<int>((ref) {
  return ref.watch(transactionRepositoryProvider).watchCount();
});

final transactionByIdProvider =
    StreamProvider.autoDispose.family<TransactionView?, int>((ref, id) {
  return ref.watch(transactionRepositoryProvider).watchById(id);
});

final categoriesProvider = StreamProvider<List<CategoryRow>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});

final allCategoriesProvider = StreamProvider<List<CategoryRow>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll(includeArchived: true);
});

final categoriesByKindProvider =
    StreamProvider.family<List<CategoryRow>, CategoryKind>((ref, kind) {
  return ref.watch(categoryRepositoryProvider).watchByKind(kind);
});

final categoriesByIdProvider = Provider<Map<int, CategoryRow>>((ref) {
  final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];
  return {for (final category in categories) category.id: category};
});

final paymentMethodsProvider = StreamProvider<List<PaymentMethodRow>>((ref) {
  return ref.watch(paymentMethodRepositoryProvider).watchAll();
});

final allPaymentMethodsProvider = StreamProvider<List<PaymentMethodRow>>((ref) {
  return ref
      .watch(paymentMethodRepositoryProvider)
      .watchAll(includeArchived: true);
});

final accountBalancesProvider = StreamProvider<List<AccountBalance>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAccountBalances();
});

/// Years that actually contain data, newest first - drives the year pickers so
/// they never offer an empty year.
final availableYearsProvider = StreamProvider<List<int>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final currentYear = ref.watch(nowProvider).year;
  return repository.watchDateBounds().map((bounds) {
    final first = bounds.first?.year ?? currentYear;
    final last = bounds.last?.year ?? currentYear;
    final from = first < last ? first : last;
    final to = (last > currentYear ? last : currentYear);
    return [for (var year = to; year >= from; year--) year];
  });
});

/// Writes, wrapped so screens get a single object to call.
class TransactionActions {
  const TransactionActions(this._ref);

  final Ref _ref;

  Future<int> add(TransactionDraft draft) =>
      _ref.read(transactionRepositoryProvider).add(draft);

  Future<void> update(TransactionDraft draft) =>
      _ref.read(transactionRepositoryProvider).update(draft);

  /// Deletes a transaction, returning the removed row so the caller can offer
  /// an undo without having to re-read it from a stream that already dropped it.
  Future<TransactionRow?> delete(int id) async {
    final repository = _ref.read(transactionRepositoryProvider);
    final row = await repository.findRow(id);
    await repository.delete(id);
    return row;
  }

  Future<void> restore(TransactionRow row) =>
      _ref.read(transactionRepositoryProvider).restore(row);
}

final transactionActionsProvider =
    Provider<TransactionActions>((ref) => TransactionActions(ref));

/// Writes for categories, wrapped so screens get a single object to call.
class CategoryActions {
  const CategoryActions(this._ref);

  final Ref _ref;

  Future<int> create({
    required String name,
    required CategoryKind kind,
    required String iconKey,
    required int colorValue,
  }) =>
      _ref.read(categoryRepositoryProvider).create(
            name: name,
            kind: kind,
            iconKey: iconKey,
            colorValue: colorValue,
          );

  Future<void> update(
    CategoryRow category, {
    String? name,
    String? iconKey,
    int? colorValue,
  }) =>
      _ref.read(categoryRepositoryProvider).updateCategory(
            category,
            name: name,
            iconKey: iconKey,
            colorValue: colorValue,
          );

  Future<int> usageCount(int id) =>
      _ref.read(categoryRepositoryProvider).usageCount(id);

  Future<void> delete(CategoryRow category) =>
      _ref.read(categoryRepositoryProvider).deleteCategory(category);

  Future<void> archive(int id, bool archived) =>
      _ref.read(categoryRepositoryProvider).setArchived(id, archived);
}

final categoryActionsProvider =
    Provider<CategoryActions>((ref) => CategoryActions(ref));

/// Writes for payment methods (accounts), wrapped the same way.
class PaymentMethodActions {
  const PaymentMethodActions(this._ref);

  final Ref _ref;

  Future<int> create({
    required String name,
    required String iconKey,
    required int colorValue,
    Money openingBalance = Money.zero,
  }) =>
      _ref.read(paymentMethodRepositoryProvider).create(
            name: name,
            iconKey: iconKey,
            colorValue: colorValue,
            openingBalance: openingBalance,
          );

  Future<void> update(
    PaymentMethodRow method, {
    String? name,
    String? iconKey,
    int? colorValue,
    Money? openingBalance,
  }) =>
      _ref.read(paymentMethodRepositoryProvider).updateMethod(
            method,
            name: name,
            iconKey: iconKey,
            colorValue: colorValue,
            openingBalance: openingBalance,
          );

  Future<int> usageCount(int id) =>
      _ref.read(paymentMethodRepositoryProvider).usageCount(id);

  Future<void> delete(PaymentMethodRow method) =>
      _ref.read(paymentMethodRepositoryProvider).deleteMethod(method);

  Future<void> archive(int id, bool archived) =>
      _ref.read(paymentMethodRepositoryProvider).setArchived(id, archived);
}

final paymentMethodActionsProvider =
    Provider<PaymentMethodActions>((ref) => PaymentMethodActions(ref));
