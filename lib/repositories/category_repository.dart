import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/errors/failures.dart';
import '../models/enums.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<CategoryRow>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.categories)
      ..orderBy([
        (c) => OrderingTerm.asc(c.kind),
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.name),
      ]);
    if (!includeArchived) {
      query.where((c) => c.isArchived.equals(false));
    }
    return query.watch();
  }

  Stream<List<CategoryRow>> watchByKind(CategoryKind kind) {
    final query = _db.select(_db.categories)
      ..where((c) => c.kind.equalsValue(kind) & c.isArchived.equals(false))
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.name),
      ]);
    return query.watch();
  }

  Future<List<CategoryRow>> allRows() => guardDatabase(
        () => _db.select(_db.categories).get(),
        failureMessage: 'Could not read categories.',
      );

  Future<CategoryRow?> findByNameAndKind(String name, CategoryKind kind) {
    return guardDatabase(
      () => (_db.select(_db.categories)
            ..where((c) => c.name.equals(name) & c.kind.equalsValue(kind)))
          .getSingleOrNull(),
      failureMessage: 'Could not read categories.',
    );
  }

  Future<int> create({
    required String name,
    required CategoryKind kind,
    required String iconKey,
    required int colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AppFailure.validation('Give the category a name.');
    }
    final existing = await findByNameAndKind(trimmed, kind);
    if (existing != null) {
      throw AppFailure.validation(
          'A ${kind.label.toLowerCase()} category called "$trimmed" already exists.');
    }
    return guardDatabase(
      () => _db.into(_db.categories).insert(
            CategoriesCompanion.insert(
              name: trimmed,
              kind: kind,
              colorValue: colorValue,
              createdAt: DateTime.now(),
              iconKey: Value(iconKey),
              sortOrder: const Value(500),
            ),
          ),
      failureMessage: 'Could not create this category.',
    );
  }

  Future<void> updateCategory(
    CategoryRow category, {
    String? name,
    String? iconKey,
    int? colorValue,
  }) async {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isEmpty) {
      throw const AppFailure.validation('Give the category a name.');
    }
    if (trimmed != null && trimmed != category.name) {
      final clash = await findByNameAndKind(trimmed, category.kind);
      if (clash != null && clash.id != category.id) {
        throw AppFailure.validation('"$trimmed" is already in use.');
      }
    }
    await guardDatabase(
      () => (_db.update(_db.categories)..where((c) => c.id.equals(category.id)))
          .write(CategoriesCompanion(
        name: trimmed == null ? const Value.absent() : Value(trimmed),
        iconKey: iconKey == null ? const Value.absent() : Value(iconKey),
        colorValue:
            colorValue == null ? const Value.absent() : Value(colorValue),
      )),
      failureMessage: 'Could not update this category.',
    );
  }

  Future<void> setArchived(int id, bool archived) => guardDatabase(
        () async {
          await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
              .write(CategoriesCompanion(isArchived: Value(archived)));
        },
        failureMessage: 'Could not update this category.',
      );

  /// How many transactions would be left uncategorised by deleting [id].
  Future<int> usageCount(int id) {
    final count = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([count])
      ..where(_db.transactions.categoryId.equals(id));
    return guardDatabase(
      () => query.map((row) => row.read(count) ?? 0).getSingle(),
      failureMessage: 'Could not check this category.',
    );
  }

  /// Deletes a user-created category. Seeded categories are archived instead so
  /// the app always keeps a working default set.
  Future<void> deleteCategory(CategoryRow category) async {
    if (category.isSystem) {
      await setArchived(category.id, true);
      return;
    }
    await guardDatabase(
      () async {
        await (_db.delete(_db.categories)
              ..where((c) => c.id.equals(category.id)))
            .go();
      },
      failureMessage: 'Could not delete this category.',
    );
  }
}
