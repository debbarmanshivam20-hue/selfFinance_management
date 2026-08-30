import 'package:drift/drift.dart';

import '../core/constants/app_constants.dart';
import '../core/database/app_database.dart';
import '../models/app_settings_model.dart';

/// Reads and writes the key/value settings table.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<AppSettingsModel> watch() {
    return _db.select(_db.appSettings).watch().map(
          (rows) => AppSettingsModel.fromMap({
            for (final row in rows) row.key: row.value,
          }),
        );
  }

  Future<AppSettingsModel> read() async {
    final rows = await _db.select(_db.appSettings).get();
    return AppSettingsModel.fromMap({
      for (final row in rows) row.key: row.value,
    });
  }

  Future<Map<String, String>> readRaw() async {
    final rows = await _db.select(_db.appSettings).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<void> put(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<void> putAll(Map<String, String> values) async {
    await _db.batch((batch) {
      for (final entry in values.entries) {
        batch.insert(
          _db.appSettings,
          AppSettingsCompanion.insert(key: entry.key, value: entry.value),
          onConflict: DoUpdate((_) =>
              AppSettingsCompanion(value: Value(entry.value))),
        );
      }
    });
  }

  Future<void> markBackupTaken(DateTime at) =>
      put(SettingsKeys.lastBackupAt, at.toIso8601String());
}
