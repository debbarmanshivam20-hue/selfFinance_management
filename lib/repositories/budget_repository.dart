import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/errors/failures.dart';
import '../core/utils/money.dart';

class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  /// Budgets defined for the financial month anchored at [year]-[month].
  Stream<List<BudgetRow>> watchForPeriod(int year, int month) {
    final query = _db.select(_db.budgets)
      ..where((b) => b.year.equals(year) & b.month.equals(month))
      ..orderBy([(b) => OrderingTerm.desc(b.amountMinor)]);
    return query.watch();
  }

  Future<List<BudgetRow>> allRows() => guardDatabase(
        () => _db.select(_db.budgets).get(),
        failureMessage: 'Could not read budgets.',
      );

  Future<BudgetRow?> find({
    required int? categoryId,
    required int year,
    required int month,
  }) {
    return guardDatabase(
      () {
        final query = _db.select(_db.budgets)
          ..where((b) => b.year.equals(year) & b.month.equals(month));
        if (categoryId == null) {
          query.where((b) => b.categoryId.isNull());
        } else {
          query.where((b) => b.categoryId.equals(categoryId));
        }
        return query.getSingleOrNull();
      },
      failureMessage: 'Could not read budgets.',
    );
  }

  /// Creates or replaces the budget for a category in one period.
  ///
  /// SQLite treats NULLs as distinct in unique indexes, so the "one overall
  /// budget per month" rule is enforced here rather than by a constraint.
  Future<void> upsert({
    required int? categoryId,
    required int year,
    required int month,
    required Money amount,
  }) async {
    if (amount.minor <= 0) {
      throw const AppFailure.validation('Enter a budget greater than zero.');
    }
    if (month < 1 || month > 12) {
      throw const AppFailure.validation('That budget period is not valid.');
    }

    final existing = await find(categoryId: categoryId, year: year, month: month);
    final now = DateTime.now();

    await guardDatabase(
      () async {
        if (existing == null) {
          await _db.into(_db.budgets).insert(
                BudgetsCompanion.insert(
                  amountMinor: amount.minor,
                  year: year,
                  month: month,
                  createdAt: now,
                  updatedAt: now,
                  categoryId: Value(categoryId),
                ),
              );
        } else {
          await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id)))
              .write(BudgetsCompanion(
            amountMinor: Value(amount.minor),
            updatedAt: Value(now),
          ));
        }
      },
      failureMessage: 'Could not save this budget.',
    );
  }

  Future<void> delete(int id) => guardDatabase(
        () async {
          await (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();
        },
        failureMessage: 'Could not delete this budget.',
      );

  /// Copies every budget from one period into another, skipping categories
  /// that already have a budget in the destination.
  Future<int> copyPeriod({
    required int fromYear,
    required int fromMonth,
    required int toYear,
    required int toMonth,
  }) async {
    return guardDatabase(
      () async {
        final source = await (_db.select(_db.budgets)
              ..where((b) => b.year.equals(fromYear) & b.month.equals(fromMonth)))
            .get();
        if (source.isEmpty) return 0;

        final existing = await (_db.select(_db.budgets)
              ..where((b) => b.year.equals(toYear) & b.month.equals(toMonth)))
            .get();
        final taken = existing.map((b) => b.categoryId).toSet();

        final pending = source.where((b) => !taken.contains(b.categoryId));
        if (pending.isEmpty) return 0;

        final now = DateTime.now();
        await _db.batch((batch) {
          batch.insertAll(
            _db.budgets,
            pending.map((b) => BudgetsCompanion.insert(
                  amountMinor: b.amountMinor,
                  year: toYear,
                  month: toMonth,
                  createdAt: now,
                  updatedAt: now,
                  categoryId: Value(b.categoryId),
                )),
          );
        });
        return pending.length;
      },
      failureMessage: 'Could not copy budgets.',
    );
  }
}
