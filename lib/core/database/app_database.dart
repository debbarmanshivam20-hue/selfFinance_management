import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../models/enums.dart';
import '../errors/failures.dart';
import 'seed_data.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The application's single source of financial truth.
///
/// Everything the user owns lives in one SQLite file inside the app's private
/// storage. Nothing is sent anywhere: there is no network code in this project
/// at all. The file survives app close, force stop and device reboot, and is
/// removed only when the user clears app data or resets the database from
/// Settings.
@DriftDatabase(
  tables: [
    Categories,
    PaymentMethods,
    Transactions,
    Budgets,
    SavingsGoals,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Used by tests to run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Timestamps are stored as ISO-8601 text rather than unix seconds. Text
  /// keeps millisecond precision and stays readable in a backup file, and the
  /// format sorts correctly, so range queries still use the date index.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          // Future schema revisions are handled here. Each step must be
          // additive or explicitly migrate data - user records are never
          // dropped to "fix" a schema change.
        },
        beforeOpen: (details) async {
          // Referential integrity is off by default in SQLite; without this
          // the ON DELETE clauses on the tables would never fire.
          await customStatement('PRAGMA foreign_keys = ON');

          // A partially seeded database (e.g. install interrupted) is repaired
          // rather than left broken.
          final categoryCount = await (selectOnly(categories)
                ..addColumns([categories.id.count()]))
              .map((row) => row.read(categories.id.count()) ?? 0)
              .getSingle();
          if (categoryCount == 0) {
            await _seed();
          }
        },
      );

  Future<void> _seed() async {
    final now = DateTime.now();
    await transaction(() async {
      await batch((batch) {
        batch.insertAll(categories, SeedData.categories(now),
            mode: InsertMode.insertOrIgnore);
        batch.insertAll(paymentMethods, SeedData.paymentMethods(now),
            mode: InsertMode.insertOrIgnore);
        batch.insertAll(
          appSettings,
          SeedData.settings(now).entries.map(
                (entry) => AppSettingsCompanion.insert(
                  key: entry.key,
                  value: entry.value,
                ),
              ),
          mode: InsertMode.insertOrIgnore,
        );
      });
    });
  }

  /// Wipes every user record and re-seeds the defaults.
  ///
  /// Only ever reached from Settings behind an explicit typed confirmation.
  Future<void> resetToFactoryDefaults() async {
    await transaction(() async {
      await delete(transactions).go();
      await delete(budgets).go();
      await delete(savingsGoals).go();
      await delete(categories).go();
      await delete(paymentMethods).go();
      await delete(appSettings).go();
    });
    await _seed();
  }

  static QueryExecutor _openConnection() {
    // `driftDatabase` stores the file in the app's private documents
    // directory, which Android preserves across restarts and reboots.
    return driftDatabase(name: 'finvault');
  }
}

/// Wraps a database call so callers never see a raw SQLite exception.
Future<T> guardDatabase<T>(
  Future<T> Function() action, {
  required String failureMessage,
}) async {
  try {
    return await action();
  } on AppFailure {
    rethrow;
  } catch (error) {
    throw AppFailure.database(failureMessage, cause: error);
  }
}
