import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/database/app_database.dart';
import '../core/errors/failures.dart';
import '../models/enums.dart';
import '../repositories/settings_repository.dart';

/// What an import will do to the existing database.
enum ImportMode {
  /// Keep everything already stored and add only what is missing.
  merge,

  /// Replace the entire database with the backup's contents.
  replace;

  String get label => switch (this) {
        ImportMode.merge => 'Merge with my data',
        ImportMode.replace => 'Replace everything',
      };

  String get description => switch (this) {
        ImportMode.merge =>
          'Adds records from the file that you do not already have. Nothing '
              'currently stored is deleted or changed.',
        ImportMode.replace =>
          'Deletes everything currently stored and restores the file exactly. '
              'This cannot be undone.',
      };
}

/// Summary of a backup file, shown before anything is written.
class BackupPreview {
  const BackupPreview({
    required this.exportedAt,
    required this.transactions,
    required this.categories,
    required this.paymentMethods,
    required this.budgets,
    required this.goals,
    required this.appVersion,
  });

  final DateTime? exportedAt;
  final int transactions;
  final int categories;
  final int paymentMethods;
  final int budgets;
  final int goals;
  final String appVersion;

  int get totalRecords =>
      transactions + categories + paymentMethods + budgets + goals;
}

/// Result of a completed import.
class ImportReport {
  const ImportReport({
    required this.mode,
    required this.transactionsAdded,
    required this.transactionsSkipped,
    required this.categoriesAdded,
    required this.paymentMethodsAdded,
    required this.budgetsAdded,
    required this.goalsAdded,
  });

  final ImportMode mode;
  final int transactionsAdded;
  final int transactionsSkipped;
  final int categoriesAdded;
  final int paymentMethodsAdded;
  final int budgetsAdded;
  final int goalsAdded;

  String get summary {
    final parts = <String>[
      if (transactionsAdded > 0) '$transactionsAdded transactions',
      if (categoriesAdded > 0) '$categoriesAdded categories',
      if (paymentMethodsAdded > 0) '$paymentMethodsAdded accounts',
      if (budgetsAdded > 0) '$budgetsAdded budgets',
      if (goalsAdded > 0) '$goalsAdded goals',
    ];
    if (parts.isEmpty) return 'Nothing new to import - your data is up to date.';
    return 'Imported ${parts.join(', ')}.';
  }
}

/// Reads and writes the app's JSON backup format.
///
/// The backup is a plain, human-readable JSON document. It is the user's own
/// data in their own file - the app never uploads it anywhere; sharing is
/// handed to the Android share sheet so the user decides where it goes.
class BackupService {
  BackupService(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  static const String formatId = 'finvault.backup';
  static const int formatVersion = 1;

  // -----------------------------------------------------------------------
  // Export
  // -----------------------------------------------------------------------

  Future<Map<String, dynamic>> buildBackupMap() async {
    return guardDatabase(
      () async {
        final categories = await _db.select(_db.categories).get();
        final methods = await _db.select(_db.paymentMethods).get();
        final transactions = await _db.select(_db.transactions).get();
        final budgets = await _db.select(_db.budgets).get();
        final goals = await _db.select(_db.savingsGoals).get();
        final settings = await _settings.readRaw();

        return <String, dynamic>{
          'format': formatId,
          'version': formatVersion,
          'exportedAt': DateTime.now().toIso8601String(),
          'app': {'name': AppInfo.name, 'version': AppInfo.version},
          'counts': {
            'transactions': transactions.length,
            'categories': categories.length,
            'paymentMethods': methods.length,
            'budgets': budgets.length,
            'savingsGoals': goals.length,
          },
          'data': {
            'categories': categories.map(_categoryToJson).toList(),
            'paymentMethods': methods.map(_methodToJson).toList(),
            'savingsGoals': goals.map(_goalToJson).toList(),
            'transactions': transactions.map(_transactionToJson).toList(),
            'budgets': budgets.map(_budgetToJson).toList(),
            'settings': settings,
          },
        };
      },
      failureMessage: 'Could not read your data for export.',
    );
  }

  /// Writes the backup to a file in the app's private cache and returns it.
  Future<File> writeBackupFile() async {
    try {
      final map = await buildBackupMap();
      final json = const JsonEncoder.withIndent('  ').convert(map);
      final directory = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(RegExp(r'[:T]'), '-');
      final file = File('${directory.path}/finvault_backup_$stamp.json');
      await file.writeAsString(json, flush: true);
      await _settings.markBackupTaken(DateTime.now());
      return file;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.storage(
        'Could not write the backup file. Check that the device has free space.',
        cause: error,
      );
    }
  }

  /// Hands the backup to the Android share sheet (save to Files, Drive, email).
  Future<void> exportAndShare() async {
    final file = await writeBackupFile();
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/json')],
          fileNameOverrides: <String>[file.uri.pathSegments.last],
          subject: '${AppInfo.name} backup',
          text: '${AppInfo.name} data backup',
        ),
      );
    } catch (error) {
      throw AppFailure.storage(
        'Could not open the share sheet. The backup file was still created.',
        cause: error,
      );
    }
  }

  // -----------------------------------------------------------------------
  // Import
  // -----------------------------------------------------------------------

  /// Parses and validates a backup file without writing anything.
  Future<({BackupPreview preview, Map<String, dynamic> payload})> inspect(
    File file,
  ) async {
    String raw;
    try {
      raw = await file.readAsString();
    } catch (error) {
      throw AppFailure.backup(
        'That file could not be read. Choose a backup file exported from '
        '${AppInfo.name}.',
        cause: error,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error) {
      throw AppFailure.backup(
        'That file is not valid JSON, so it cannot be imported.',
        cause: error,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AppFailure.backup('That file is not a $formatId file.');
    }
    if (decoded['format'] != formatId) {
      throw AppFailure.backup(
        'That file was not created by ${AppInfo.name}.',
      );
    }

    final version = _asInt(decoded['version']);
    if (version == null || version > formatVersion) {
      throw AppFailure.backup(
        'That backup was made by a newer version of ${AppInfo.name}. '
        'Update the app and try again.',
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const AppFailure.backup('That backup file is incomplete.');
    }

    final preview = BackupPreview(
      exportedAt: DateTime.tryParse('${decoded['exportedAt']}'),
      transactions: _listOf(data['transactions']).length,
      categories: _listOf(data['categories']).length,
      paymentMethods: _listOf(data['paymentMethods']).length,
      budgets: _listOf(data['budgets']).length,
      goals: _listOf(data['savingsGoals']).length,
      appVersion: '${(decoded['app'] as Map?)?['version'] ?? 'unknown'}',
    );

    if (preview.totalRecords == 0) {
      throw const AppFailure.backup('That backup file has no records in it.');
    }

    return (preview: preview, payload: decoded);
  }

  /// Applies a previously inspected backup.
  ///
  /// The whole import runs inside one SQLite transaction: if any record is
  /// malformed the database is rolled back untouched, so a bad file can never
  /// leave the user with half-restored finances.
  Future<ImportReport> import(
    Map<String, dynamic> payload,
    ImportMode mode,
  ) async {
    final data = payload['data'] as Map<String, dynamic>;

    var categoriesAdded = 0;
    var methodsAdded = 0;
    var goalsAdded = 0;
    var budgetsAdded = 0;
    var transactionsAdded = 0;
    var transactionsSkipped = 0;

    try {
      await _db.transaction(() async {
        if (mode == ImportMode.replace) {
          await _db.delete(_db.transactions).go();
          await _db.delete(_db.budgets).go();
          await _db.delete(_db.savingsGoals).go();
          await _db.delete(_db.categories).go();
          await _db.delete(_db.paymentMethods).go();
        }

        // --- categories -------------------------------------------------
        final categoryIdMap = <int, int>{};
        final existingCategories = await _db.select(_db.categories).get();
        final categoryKey = <String, int>{
          for (final row in existingCategories) '${row.kind.name}|${row.name.toLowerCase()}': row.id,
        };

        for (final raw in _listOf(data['categories'])) {
          final name = _asString(raw['name']);
          final kind = CategoryKind.tryParse(_asString(raw['kind']));
          final sourceId = _asInt(raw['id']);
          if (name == null || kind == null || sourceId == null) continue;

          final key = '${kind.name}|${name.toLowerCase()}';
          final existing = categoryKey[key];
          if (existing != null) {
            categoryIdMap[sourceId] = existing;
            continue;
          }
          final newId = await _db.into(_db.categories).insert(
                CategoriesCompanion.insert(
                  name: name,
                  kind: kind,
                  colorValue: _asInt(raw['colorValue']) ?? 0xFF64748B,
                  createdAt: _asDate(raw['createdAt']) ?? DateTime.now(),
                  iconKey: Value(_asString(raw['iconKey']) ?? 'category'),
                  isSystem: Value(raw['isSystem'] == true),
                  isArchived: Value(raw['isArchived'] == true),
                  sortOrder: Value(_asInt(raw['sortOrder']) ?? 500),
                ),
              );
          categoryKey[key] = newId;
          categoryIdMap[sourceId] = newId;
          categoriesAdded++;
        }

        // --- payment methods --------------------------------------------
        final methodIdMap = <int, int>{};
        final existingMethods = await _db.select(_db.paymentMethods).get();
        final methodKey = <String, int>{
          for (final row in existingMethods) row.name.toLowerCase(): row.id,
        };

        for (final raw in _listOf(data['paymentMethods'])) {
          final name = _asString(raw['name']);
          final sourceId = _asInt(raw['id']);
          if (name == null || sourceId == null) continue;

          final existing = methodKey[name.toLowerCase()];
          if (existing != null) {
            methodIdMap[sourceId] = existing;
            continue;
          }
          final newId = await _db.into(_db.paymentMethods).insert(
                PaymentMethodsCompanion.insert(
                  name: name,
                  colorValue: _asInt(raw['colorValue']) ?? 0xFF64748B,
                  createdAt: _asDate(raw['createdAt']) ?? DateTime.now(),
                  iconKey: Value(_asString(raw['iconKey']) ?? 'wallet'),
                  openingBalanceMinor:
                      Value(_asInt(raw['openingBalanceMinor']) ?? 0),
                  isSystem: Value(raw['isSystem'] == true),
                  isArchived: Value(raw['isArchived'] == true),
                  sortOrder: Value(_asInt(raw['sortOrder']) ?? 500),
                ),
              );
          methodKey[name.toLowerCase()] = newId;
          methodIdMap[sourceId] = newId;
          methodsAdded++;
        }

        // --- savings goals ----------------------------------------------
        final goalIdMap = <int, int>{};
        final existingGoals = await _db.select(_db.savingsGoals).get();
        final goalKey = <String, int>{
          for (final row in existingGoals) row.name.toLowerCase(): row.id,
        };

        for (final raw in _listOf(data['savingsGoals'])) {
          final name = _asString(raw['name']);
          final target = _asInt(raw['targetMinor']);
          final sourceId = _asInt(raw['id']);
          if (name == null || target == null || sourceId == null) continue;

          final existing = goalKey[name.toLowerCase()];
          if (existing != null) {
            goalIdMap[sourceId] = existing;
            continue;
          }
          final now = DateTime.now();
          final newId = await _db.into(_db.savingsGoals).insert(
                SavingsGoalsCompanion.insert(
                  name: name,
                  targetMinor: target,
                  colorValue: _asInt(raw['colorValue']) ?? 0xFF10B981,
                  createdAt: _asDate(raw['createdAt']) ?? now,
                  updatedAt: _asDate(raw['updatedAt']) ?? now,
                  openingMinor: Value(_asInt(raw['openingMinor']) ?? 0),
                  targetDate: Value(_asDate(raw['targetDate'])),
                  iconKey: Value(_asString(raw['iconKey']) ?? 'goal'),
                  note: Value(_asString(raw['note'])),
                  isArchived: Value(raw['isArchived'] == true),
                ),
              );
          goalKey[name.toLowerCase()] = newId;
          goalIdMap[sourceId] = newId;
          goalsAdded++;
        }

        // --- transactions -----------------------------------------------
        // A fingerprint of the rows already present lets a merge run twice
        // without duplicating the user's history.
        final existingTransactions = await _db.select(_db.transactions).get();
        final fingerprints = existingTransactions.map(_fingerprint).toSet();

        for (final raw in _listOf(data['transactions'])) {
          final type = TransactionType.tryParse(_asString(raw['type']));
          final amount = _asInt(raw['amountMinor']);
          final date = _asDate(raw['date']);
          final title = _asString(raw['title']);
          if (type == null || amount == null || date == null || title == null) {
            continue;
          }
          if (amount <= 0) continue;

          final sourceCategory = _asInt(raw['categoryId']);
          final sourceMethod = _asInt(raw['paymentMethodId']);
          final sourceToMethod = _asInt(raw['toPaymentMethodId']);
          final sourceGoal = _asInt(raw['goalId']);

          final companion = TransactionsCompanion.insert(
            type: type,
            amountMinor: amount,
            date: date,
            title: title,
            createdAt: _asDate(raw['createdAt']) ?? date,
            updatedAt: _asDate(raw['updatedAt']) ?? date,
            categoryId: Value(
                sourceCategory == null ? null : categoryIdMap[sourceCategory]),
            paymentMethodId:
                Value(sourceMethod == null ? null : methodIdMap[sourceMethod]),
            toPaymentMethodId: Value(
                sourceToMethod == null ? null : methodIdMap[sourceToMethod]),
            goalId: Value(sourceGoal == null ? null : goalIdMap[sourceGoal]),
            description: Value(_asString(raw['description'])),
            notes: Value(_asString(raw['notes'])),
            currencyCode: Value(_asString(raw['currencyCode']) ?? 'INR'),
          );

          final key = '${type.name}|$amount|${date.toIso8601String()}|$title';
          if (mode == ImportMode.merge && fingerprints.contains(key)) {
            transactionsSkipped++;
            continue;
          }
          await _db.into(_db.transactions).insert(companion);
          fingerprints.add(key);
          transactionsAdded++;
        }

        // --- budgets ------------------------------------------------------
        final existingBudgets = await _db.select(_db.budgets).get();
        final budgetKeys = existingBudgets
            .map((b) => '${b.categoryId}|${b.year}|${b.month}')
            .toSet();

        for (final raw in _listOf(data['budgets'])) {
          final amount = _asInt(raw['amountMinor']);
          final year = _asInt(raw['year']);
          final month = _asInt(raw['month']);
          if (amount == null || year == null || month == null) continue;
          if (amount <= 0 || month < 1 || month > 12) continue;

          final sourceCategory = _asInt(raw['categoryId']);
          final mapped =
              sourceCategory == null ? null : categoryIdMap[sourceCategory];
          final key = '$mapped|$year|$month';
          if (budgetKeys.contains(key)) continue;

          final now = DateTime.now();
          await _db.into(_db.budgets).insert(
                BudgetsCompanion.insert(
                  amountMinor: amount,
                  year: year,
                  month: month,
                  createdAt: _asDate(raw['createdAt']) ?? now,
                  updatedAt: _asDate(raw['updatedAt']) ?? now,
                  categoryId: Value(mapped),
                ),
              );
          budgetKeys.add(key);
          budgetsAdded++;
        }

        // --- settings -----------------------------------------------------
        // Preferences are only restored on a full replace: a merge should
        // never silently change the user's theme or currency.
        if (mode == ImportMode.replace) {
          final settings = data['settings'];
          if (settings is Map) {
            await _settings.putAll(<String, String>{
              for (final entry in settings.entries)
                '${entry.key}': '${entry.value}',
            });
          }
        }
      });
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.backup(
        'The import was cancelled and your data was left unchanged. The '
        'backup file appears to be damaged.',
        cause: error,
      );
    }

    return ImportReport(
      mode: mode,
      transactionsAdded: transactionsAdded,
      transactionsSkipped: transactionsSkipped,
      categoriesAdded: categoriesAdded,
      paymentMethodsAdded: methodsAdded,
      budgetsAdded: budgetsAdded,
      goalsAdded: goalsAdded,
    );
  }

  static String _fingerprint(TransactionRow row) =>
      '${row.type.name}|${row.amountMinor}|${row.date.toIso8601String()}|${row.title}';

  // -----------------------------------------------------------------------
  // JSON helpers - every one of these tolerates a missing or wrong-typed value
  // -----------------------------------------------------------------------

  static List<Map<String, dynamic>> _listOf(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _asDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }

  static Map<String, dynamic> _categoryToJson(CategoryRow row) => {
        'id': row.id,
        'name': row.name,
        'kind': row.kind.name,
        'iconKey': row.iconKey,
        'colorValue': row.colorValue,
        'isSystem': row.isSystem,
        'isArchived': row.isArchived,
        'sortOrder': row.sortOrder,
        'createdAt': row.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> _methodToJson(PaymentMethodRow row) => {
        'id': row.id,
        'name': row.name,
        'iconKey': row.iconKey,
        'colorValue': row.colorValue,
        'openingBalanceMinor': row.openingBalanceMinor,
        'isSystem': row.isSystem,
        'isArchived': row.isArchived,
        'sortOrder': row.sortOrder,
        'createdAt': row.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> _goalToJson(SavingsGoalRow row) => {
        'id': row.id,
        'name': row.name,
        'targetMinor': row.targetMinor,
        'openingMinor': row.openingMinor,
        'targetDate': row.targetDate?.toIso8601String(),
        'iconKey': row.iconKey,
        'colorValue': row.colorValue,
        'note': row.note,
        'isArchived': row.isArchived,
        'createdAt': row.createdAt.toIso8601String(),
        'updatedAt': row.updatedAt.toIso8601String(),
      };

  static Map<String, dynamic> _transactionToJson(TransactionRow row) => {
        'id': row.id,
        'type': row.type.name,
        'amountMinor': row.amountMinor,
        'categoryId': row.categoryId,
        'paymentMethodId': row.paymentMethodId,
        'toPaymentMethodId': row.toPaymentMethodId,
        'goalId': row.goalId,
        'date': row.date.toIso8601String(),
        'title': row.title,
        'description': row.description,
        'notes': row.notes,
        'currencyCode': row.currencyCode,
        'createdAt': row.createdAt.toIso8601String(),
        'updatedAt': row.updatedAt.toIso8601String(),
      };

  static Map<String, dynamic> _budgetToJson(BudgetRow row) => {
        'id': row.id,
        'categoryId': row.categoryId,
        'amountMinor': row.amountMinor,
        'year': row.year,
        'month': row.month,
        'createdAt': row.createdAt.toIso8601String(),
        'updatedAt': row.updatedAt.toIso8601String(),
      };
}
