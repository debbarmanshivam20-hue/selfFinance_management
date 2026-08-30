import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/errors/failures.dart';
import '../core/utils/date_range.dart';
import '../core/utils/money.dart';
import '../models/analytics.dart';
import '../models/enums.dart';
import '../models/transaction_draft.dart';
import '../models/transaction_filter.dart';
import '../models/transaction_view.dart';

/// All reads and writes of transaction data.
///
/// Every read is exposed as a `Stream` backed by drift's query watching: when
/// a row changes, SQLite tells drift which tables were touched and every
/// affected stream re-emits. That is what keeps the dashboard, charts,
/// analytics and history in sync without any manual cache invalidation.
class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  /// The `to` account needs its own alias - a transaction joins
  /// `payment_methods` twice (source and destination).
  late final $PaymentMethodsTable _destination =
      _db.alias(_db.paymentMethods, 'destination_account');

  // ---------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------

  /// Inserts a transaction and returns its new id.
  ///
  /// The write is committed before this future completes, so data is durable
  /// the moment the user sees the success message.
  Future<int> add(TransactionDraft draft) {
    draft.validate();
    return guardDatabase(
      () => _db.into(_db.transactions).insert(
            draft.toCompanion(now: DateTime.now()),
          ),
      failureMessage: 'Could not save this transaction. Please try again.',
    );
  }

  Future<void> update(TransactionDraft draft) {
    draft.validate();
    final id = draft.id;
    if (id == null) {
      throw const AppFailure.validation('This entry no longer exists.');
    }
    return guardDatabase(
      () async {
        final updated = await (_db.update(_db.transactions)
              ..where((t) => t.id.equals(id)))
            .write(draft.toCompanion(now: DateTime.now()));
        if (updated == 0) {
          throw const AppFailure.notFound('This entry no longer exists.');
        }
      },
      failureMessage: 'Could not update this transaction. Please try again.',
    );
  }

  Future<void> delete(int id) {
    return guardDatabase(
      () async {
        await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
      },
      failureMessage: 'Could not delete this transaction. Please try again.',
    );
  }

  /// Restores a previously deleted row with its original id (used by undo).
  Future<void> restore(TransactionRow row) {
    return guardDatabase(
      () => _db.into(_db.transactions).insert(row, mode: InsertMode.replace),
      failureMessage: 'Could not restore this transaction.',
    );
  }

  Future<int> deleteAll() {
    return guardDatabase(
      () => _db.delete(_db.transactions).go(),
      failureMessage: 'Could not clear transactions.',
    );
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  JoinedSelectStatement<HasResultSet, dynamic> _joined() {
    return _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
      leftOuterJoin(
        _db.paymentMethods,
        _db.paymentMethods.id.equalsExp(_db.transactions.paymentMethodId),
      ),
      leftOuterJoin(
        _destination,
        _destination.id.equalsExp(_db.transactions.toPaymentMethodId),
      ),
      leftOuterJoin(
        _db.savingsGoals,
        _db.savingsGoals.id.equalsExp(_db.transactions.goalId),
      ),
    ]);
  }

  TransactionView _map(TypedResult row) => TransactionView(
        row: row.readTable(_db.transactions),
        category: row.readTableOrNull(_db.categories),
        source: row.readTableOrNull(_db.paymentMethods),
        destination: row.readTableOrNull(_destination),
        goal: row.readTableOrNull(_db.savingsGoals),
      );

  Expression<bool> _inRange(DateRange range) =>
      _db.transactions.date.isBiggerOrEqualValue(range.start) &
      _db.transactions.date.isSmallerThanValue(range.end);

  /// Watches the transaction list for [filter].
  Stream<List<TransactionView>> watchFiltered(
    TransactionFilter filter,
    FinancialCalendar calendar, {
    int? limit,
  }) {
    final query = _joined();

    final range = filter.resolveRange(calendar);
    if (range != null) query.where(_inRange(range));

    if (filter.types.isNotEmpty) {
      query.where(_db.transactions.type.isInValues(filter.types.toList()));
    }
    if (filter.categoryId != null) {
      query.where(_db.transactions.categoryId.equals(filter.categoryId!));
    }
    if (filter.paymentMethodId != null) {
      final id = filter.paymentMethodId!;
      query.where(_db.transactions.paymentMethodId.equals(id) |
          _db.transactions.toPaymentMethodId.equals(id));
    }

    final search = filter.query.trim().toLowerCase();
    if (search.isNotEmpty) {
      // `%` is stripped so a stray wildcard cannot turn the query into
      // "match everything".
      final pattern = '%${search.replaceAll('%', '')}%';
      query.where(
        _db.transactions.title.lower().like(pattern) |
            _db.transactions.description.lower().like(pattern) |
            _db.transactions.notes.lower().like(pattern) |
            _db.categories.name.lower().like(pattern) |
            _db.paymentMethods.name.lower().like(pattern),
      );
    }

    query.orderBy(_orderingFor(filter.sort));
    if (limit != null) query.limit(limit);

    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  List<OrderingTerm> _orderingFor(TransactionSort sort) => switch (sort) {
        // The id tiebreaker keeps ordering stable for same-day entries.
        TransactionSort.dateDesc => [
            OrderingTerm.desc(_db.transactions.date),
            OrderingTerm.desc(_db.transactions.id),
          ],
        TransactionSort.dateAsc => [
            OrderingTerm.asc(_db.transactions.date),
            OrderingTerm.asc(_db.transactions.id),
          ],
        TransactionSort.amountDesc => [
            OrderingTerm.desc(_db.transactions.amountMinor),
            OrderingTerm.desc(_db.transactions.date),
          ],
        TransactionSort.amountAsc => [
            OrderingTerm.asc(_db.transactions.amountMinor),
            OrderingTerm.desc(_db.transactions.date),
          ],
        TransactionSort.titleAsc => [
            OrderingTerm.asc(_db.transactions.title),
            OrderingTerm.desc(_db.transactions.date),
          ],
      };

  /// The newest [limit] entries, for the dashboard's recent activity list.
  Stream<List<TransactionView>> watchRecent({int limit = 6}) {
    final query = _joined()
      ..orderBy([
        OrderingTerm.desc(_db.transactions.date),
        OrderingTerm.desc(_db.transactions.id),
      ])
      ..limit(limit);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  Stream<TransactionView?> watchById(int id) {
    final query = _joined()..where(_db.transactions.id.equals(id));
    return query.watchSingleOrNull().map((row) => row == null ? null : _map(row));
  }

  Future<TransactionRow?> findRow(int id) {
    return guardDatabase(
      () => (_db.select(_db.transactions)..where((t) => t.id.equals(id)))
          .getSingleOrNull(),
      failureMessage: 'Could not load this transaction.',
    );
  }

  Future<List<TransactionRow>> allRows() {
    return guardDatabase(
      () => (_db.select(_db.transactions)
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get(),
      failureMessage: 'Could not read transactions.',
    );
  }

  Stream<int> watchCount() {
    final count = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // ---------------------------------------------------------------------
  // Aggregates - summed by SQLite, never by looping in the UI
  // ---------------------------------------------------------------------

  /// Totals per transaction type for [range] (or all time when null).
  Stream<PeriodTotals> watchTotals(DateRange? range) {
    final sum = _db.transactions.amountMinor.sum();
    final count = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.type, sum, count])
      ..groupBy([_db.transactions.type]);
    if (range != null) query.where(_inRange(range));

    final window = range ??
        DateRange(start: DateTime(1970), end: DateTime(9999), label: 'All time');

    return query.watch().map((rows) {
      var income = Money.zero;
      var expense = Money.zero;
      var savings = Money.zero;
      var transfer = Money.zero;
      var total = 0;

      for (final row in rows) {
        final type = row.readWithConverter(_db.transactions.type);
        final amount = Money(row.read(sum) ?? 0);
        total += row.read(count) ?? 0;
        switch (type) {
          case TransactionType.income:
            income = amount;
          case TransactionType.expense:
            expense = amount;
          case TransactionType.savings:
            savings = amount;
          case TransactionType.transfer:
            transfer = amount;
          case null:
            break;
        }
      }

      return PeriodTotals(
        range: window,
        income: income,
        expense: expense,
        savings: savings,
        transferVolume: transfer,
        transactionCount: total,
      );
    });
  }

  /// One bar per day in [range] - days with no spending are emitted as zero so
  /// the chart shows a real gap instead of collapsing the axis.
  Stream<List<DailyPoint>> watchDailySeries(
    DateRange range, {
    TransactionType type = TransactionType.expense,
  }) {
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.date, _db.transactions.amountMinor])
      ..where(_inRange(range) & _db.transactions.type.equalsValue(type));

    return query.watch().map((rows) {
      final buckets = <DateTime, int>{
        for (final day in range.days) day: 0,
      };
      for (final row in rows) {
        final date = row.read(_db.transactions.date);
        final amount = row.read(_db.transactions.amountMinor) ?? 0;
        if (date == null) continue;
        final key = DateTime(date.year, date.month, date.day);
        buckets[key] = (buckets[key] ?? 0) + amount;
      }
      return buckets.entries
          .map((entry) => DailyPoint(date: entry.key, amount: Money(entry.value)))
          .toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  /// Income / expense / savings for each of the 12 financial months of [year].
  Stream<List<MonthlyPoint>> watchMonthlySeries(
    int year,
    FinancialCalendar calendar,
  ) {
    final range = calendar.year(year);
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.transactions.type,
        _db.transactions.date,
        _db.transactions.amountMinor,
      ])
      ..where(_inRange(range) &
          _db.transactions.type.isNotInValues([TransactionType.transfer]));

    return query.watch().map((rows) => _foldMonthly(rows, year, calendar));
  }

  List<MonthlyPoint> _foldMonthly(
    List<TypedResult> rows,
    int year,
    FinancialCalendar calendar,
  ) {
    final months = calendar.monthsOfYear(year);
    final income = <DateTime, int>{for (final m in months) m.start: 0};
    final expense = <DateTime, int>{for (final m in months) m.start: 0};
    final savings = <DateTime, int>{for (final m in months) m.start: 0};

    for (final row in rows) {
      final date = row.read(_db.transactions.date);
      final type = row.readWithConverter(_db.transactions.type);
      final amount = row.read(_db.transactions.amountMinor) ?? 0;
      if (date == null || type == null) continue;
      final key = calendar.month(date).start;
      switch (type) {
        case TransactionType.income:
          if (income.containsKey(key)) income[key] = income[key]! + amount;
        case TransactionType.expense:
          if (expense.containsKey(key)) expense[key] = expense[key]! + amount;
        case TransactionType.savings:
          if (savings.containsKey(key)) savings[key] = savings[key]! + amount;
        case TransactionType.transfer:
          break;
      }
    }

    return months
        .map((month) => MonthlyPoint(
              anchor: month.start,
              label: calendar.shortMonthLabel(month.start),
              income: Money(income[month.start] ?? 0),
              expense: Money(expense[month.start] ?? 0),
              savings: Money(savings[month.start] ?? 0),
            ))
        .toList(growable: false);
  }

  /// Category breakdown for one transaction type within [range].
  Stream<List<CategoryTotal>> watchCategoryTotals({
    required DateRange? range,
    TransactionType type = TransactionType.expense,
  }) {
    final sum = _db.transactions.amountMinor.sum();
    final count = _db.transactions.id.count();

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.categories.id,
        _db.categories.name,
        _db.categories.iconKey,
        _db.categories.colorValue,
        sum,
        count,
      ])
      ..join([
        leftOuterJoin(
          _db.categories,
          _db.categories.id.equalsExp(_db.transactions.categoryId),
        ),
      ])
      ..groupBy([_db.transactions.categoryId])
      ..orderBy([OrderingTerm.desc(sum)]);

    query.where(_db.transactions.type.equalsValue(type));
    if (range != null) query.where(_inRange(range));

    return query.watch().map((rows) {
      final entries = rows
          .map((row) => (
                id: row.read(_db.categories.id),
                name: row.read(_db.categories.name) ?? 'Uncategorised',
                iconKey: row.read(_db.categories.iconKey) ?? 'category',
                color: row.read(_db.categories.colorValue) ?? 0xFF64748B,
                total: row.read(sum) ?? 0,
                count: row.read(count) ?? 0,
              ))
          .where((entry) => entry.total > 0)
          .toList();

      final grandTotal = entries.fold<int>(0, (acc, e) => acc + e.total);

      return entries
          .map((entry) => CategoryTotal(
                categoryId: entry.id,
                name: entry.name,
                iconKey: entry.iconKey,
                colorValue: entry.color,
                total: Money(entry.total),
                transactionCount: entry.count,
                share: grandTotal == 0 ? 0 : entry.total * 100 / grandTotal,
              ))
          .toList(growable: false);
    });
  }

  /// Total spent against one category inside [range] - used by budgets.
  Stream<Map<int?, Money>> watchSpendByCategory(DateRange range) {
    final sum = _db.transactions.amountMinor.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.categoryId, sum])
      ..where(_inRange(range) &
          _db.transactions.type.equalsValue(TransactionType.expense))
      ..groupBy([_db.transactions.categoryId]);

    return query.watch().map((rows) => <int?, Money>{
          for (final row in rows)
            row.read(_db.transactions.categoryId): Money(row.read(sum) ?? 0),
        });
  }

  /// Contributions made towards each savings goal.
  Stream<Map<int, ({Money total, int count, DateTime? last})>>
      watchGoalContributions() {
    final sum = _db.transactions.amountMinor.sum();
    final count = _db.transactions.id.count();
    final last = _db.transactions.date.max();

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.goalId, sum, count, last])
      ..where(_db.transactions.goalId.isNotNull() &
          _db.transactions.type.equalsValue(TransactionType.savings))
      ..groupBy([_db.transactions.goalId]);

    return query.watch().map((rows) {
      final result = <int, ({Money total, int count, DateTime? last})>{};
      for (final row in rows) {
        final goalId = row.read(_db.transactions.goalId);
        if (goalId == null) continue;
        result[goalId] = (
          total: Money(row.read(sum) ?? 0),
          count: row.read(count) ?? 0,
          last: row.read(last),
        );
      }
      return result;
    });
  }

  /// Current balance of every active account.
  ///
  /// Written as one SQL statement so a transfer's two sides are always read
  /// from a single consistent snapshot.
  Stream<List<AccountBalance>> watchAccountBalances() {
    const sql = '''
      SELECT
        pm.id AS account_id,
        pm.opening_balance_minor
          + COALESCE((SELECT SUM(t.amount_minor) FROM transactions t
                      WHERE t.payment_method_id = pm.id
                        AND t.type = 'income'), 0)
          + COALESCE((SELECT SUM(t.amount_minor) FROM transactions t
                      WHERE t.to_payment_method_id = pm.id
                        AND t.type = 'transfer'), 0)
          - COALESCE((SELECT SUM(t.amount_minor) FROM transactions t
                      WHERE t.payment_method_id = pm.id
                        AND t.type IN ('expense', 'savings', 'transfer')), 0)
          AS balance_minor
      FROM payment_methods pm
      WHERE pm.is_archived = 0
      ORDER BY pm.sort_order ASC, pm.name ASC
    ''';

    return _db
        .customSelect(sql, readsFrom: {_db.transactions, _db.paymentMethods})
        .watch()
        .asyncMap((rows) async {
      final accounts = await _db.select(_db.paymentMethods).get();
      final byId = {for (final account in accounts) account.id: account};
      return rows
          .map((row) {
            final account = byId[row.read<int>('account_id')];
            if (account == null) return null;
            return AccountBalance(
              account: account,
              balance: Money(row.read<int>('balance_minor')),
            );
          })
          .whereType<AccountBalance>()
          .toList(growable: false);
    });
  }

  /// Oldest and newest transaction dates, used to build year pickers without
  /// scanning the table in Dart.
  Stream<({DateTime? first, DateTime? last})> watchDateBounds() {
    final min = _db.transactions.date.min();
    final max = _db.transactions.date.max();
    final query = _db.selectOnly(_db.transactions)..addColumns([min, max]);
    return query
        .watchSingle()
        .map((row) => (first: row.read(min), last: row.read(max)));
  }
}
