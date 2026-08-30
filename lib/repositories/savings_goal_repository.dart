import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/errors/failures.dart';
import '../core/utils/money.dart';

class SavingsGoalRepository {
  SavingsGoalRepository(this._db);

  final AppDatabase _db;

  Stream<List<SavingsGoalRow>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.savingsGoals)
      ..orderBy([
        (g) => OrderingTerm.asc(g.isArchived),
        (g) => OrderingTerm.asc(g.targetDate),
        (g) => OrderingTerm.desc(g.createdAt),
      ]);
    if (!includeArchived) {
      query.where((g) => g.isArchived.equals(false));
    }
    return query.watch();
  }

  Stream<SavingsGoalRow?> watchById(int id) =>
      (_db.select(_db.savingsGoals)..where((g) => g.id.equals(id)))
          .watchSingleOrNull();

  Future<List<SavingsGoalRow>> allRows() => guardDatabase(
        () => _db.select(_db.savingsGoals).get(),
        failureMessage: 'Could not read savings goals.',
      );

  Future<int> create({
    required String name,
    required Money target,
    Money opening = Money.zero,
    DateTime? targetDate,
    String iconKey = 'goal',
    required int colorValue,
    String? note,
  }) async {
    _validate(name: name, target: target, opening: opening, targetDate: targetDate);
    final now = DateTime.now();
    return guardDatabase(
      () => _db.into(_db.savingsGoals).insert(
            SavingsGoalsCompanion.insert(
              name: name.trim(),
              targetMinor: target.minor,
              colorValue: colorValue,
              createdAt: now,
              updatedAt: now,
              openingMinor: Value(opening.minor),
              targetDate: Value(targetDate),
              iconKey: Value(iconKey),
              note: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
            ),
          ),
      failureMessage: 'Could not create this goal.',
    );
  }

  Future<void> updateGoal(
    int id, {
    required String name,
    required Money target,
    required Money opening,
    DateTime? targetDate,
    bool clearTargetDate = false,
    required String iconKey,
    required int colorValue,
    String? note,
  }) async {
    _validate(name: name, target: target, opening: opening, targetDate: targetDate);
    await guardDatabase(
      () async {
        final updated = await (_db.update(_db.savingsGoals)
              ..where((g) => g.id.equals(id)))
            .write(SavingsGoalsCompanion(
          name: Value(name.trim()),
          targetMinor: Value(target.minor),
          openingMinor: Value(opening.minor),
          targetDate:
              clearTargetDate ? const Value(null) : Value(targetDate),
          iconKey: Value(iconKey),
          colorValue: Value(colorValue),
          note: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
          updatedAt: Value(DateTime.now()),
        ));
        if (updated == 0) {
          throw const AppFailure.notFound('This goal no longer exists.');
        }
      },
      failureMessage: 'Could not update this goal.',
    );
  }

  void _validate({
    required String name,
    required Money target,
    required Money opening,
    DateTime? targetDate,
  }) {
    if (name.trim().isEmpty) {
      throw const AppFailure.validation('Give the goal a name.');
    }
    if (target.minor <= 0) {
      throw const AppFailure.validation('Set a target greater than zero.');
    }
    if (opening.isNegative) {
      throw const AppFailure.validation(
          'Starting amount cannot be negative.');
    }
    if (opening > target) {
      throw const AppFailure.validation(
          'Starting amount cannot be more than the target.');
    }
  }

  Future<void> setArchived(int id, bool archived) => guardDatabase(
        () async {
          await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(id)))
              .write(SavingsGoalsCompanion(
            isArchived: Value(archived),
            updatedAt: Value(DateTime.now()),
          ));
        },
        failureMessage: 'Could not update this goal.',
      );

  /// Deleting a goal leaves its savings transactions intact - the money was
  /// really saved, it is simply no longer earmarked (ON DELETE SET NULL).
  Future<void> delete(int id) => guardDatabase(
        () async {
          await (_db.delete(_db.savingsGoals)..where((g) => g.id.equals(id)))
              .go();
        },
        failureMessage: 'Could not delete this goal.',
      );
}
