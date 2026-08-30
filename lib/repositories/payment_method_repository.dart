import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/errors/failures.dart';
import '../core/utils/money.dart';

class PaymentMethodRepository {
  PaymentMethodRepository(this._db);

  final AppDatabase _db;

  Stream<List<PaymentMethodRow>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.paymentMethods)
      ..orderBy([
        (p) => OrderingTerm.asc(p.sortOrder),
        (p) => OrderingTerm.asc(p.name),
      ]);
    if (!includeArchived) {
      query.where((p) => p.isArchived.equals(false));
    }
    return query.watch();
  }

  Future<List<PaymentMethodRow>> allRows() => guardDatabase(
        () => _db.select(_db.paymentMethods).get(),
        failureMessage: 'Could not read payment methods.',
      );

  Future<PaymentMethodRow?> findByName(String name) => guardDatabase(
        () => (_db.select(_db.paymentMethods)..where((p) => p.name.equals(name)))
            .getSingleOrNull(),
        failureMessage: 'Could not read payment methods.',
      );

  Future<int> create({
    required String name,
    required String iconKey,
    required int colorValue,
    Money openingBalance = Money.zero,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AppFailure.validation('Give the account a name.');
    }
    if (await findByName(trimmed) != null) {
      throw AppFailure.validation('"$trimmed" already exists.');
    }
    return guardDatabase(
      () => _db.into(_db.paymentMethods).insert(
            PaymentMethodsCompanion.insert(
              name: trimmed,
              colorValue: colorValue,
              createdAt: DateTime.now(),
              iconKey: Value(iconKey),
              openingBalanceMinor: Value(openingBalance.minor),
              sortOrder: const Value(500),
            ),
          ),
      failureMessage: 'Could not create this account.',
    );
  }

  Future<void> updateMethod(
    PaymentMethodRow method, {
    String? name,
    String? iconKey,
    int? colorValue,
    Money? openingBalance,
  }) async {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isEmpty) {
      throw const AppFailure.validation('Give the account a name.');
    }
    if (trimmed != null && trimmed != method.name) {
      final clash = await findByName(trimmed);
      if (clash != null && clash.id != method.id) {
        throw AppFailure.validation('"$trimmed" is already in use.');
      }
    }
    await guardDatabase(
      () => (_db.update(_db.paymentMethods)
            ..where((p) => p.id.equals(method.id)))
          .write(PaymentMethodsCompanion(
        name: trimmed == null ? const Value.absent() : Value(trimmed),
        iconKey: iconKey == null ? const Value.absent() : Value(iconKey),
        colorValue:
            colorValue == null ? const Value.absent() : Value(colorValue),
        openingBalanceMinor: openingBalance == null
            ? const Value.absent()
            : Value(openingBalance.minor),
      )),
      failureMessage: 'Could not update this account.',
    );
  }

  Future<void> setArchived(int id, bool archived) => guardDatabase(
        () async {
          await (_db.update(_db.paymentMethods)..where((p) => p.id.equals(id)))
              .write(PaymentMethodsCompanion(isArchived: Value(archived)));
        },
        failureMessage: 'Could not update this account.',
      );

  Future<int> usageCount(int id) {
    final count = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([count])
      ..where(_db.transactions.paymentMethodId.equals(id) |
          _db.transactions.toPaymentMethodId.equals(id));
    return guardDatabase(
      () => query.map((row) => row.read(count) ?? 0).getSingle(),
      failureMessage: 'Could not check this account.',
    );
  }

  Future<void> deleteMethod(PaymentMethodRow method) async {
    if (method.isSystem) {
      await setArchived(method.id, true);
      return;
    }
    await guardDatabase(
      () async {
        await (_db.delete(_db.paymentMethods)
              ..where((p) => p.id.equals(method.id)))
            .go();
      },
      failureMessage: 'Could not delete this account.',
    );
  }
}
