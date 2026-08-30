import 'package:drift/drift.dart';

import '../../models/enums.dart';

/// Money is persisted as a whole number of minor units in `*Minor` columns.
/// See [Money] for why this project never stores a REAL for an amount.

@TableIndex(name: 'idx_categories_kind', columns: {#kind})
@DataClassName('CategoryRow')
class Categories extends Table {
  @override
  String get tableName => 'categories';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get kind => textEnum<CategoryKind>()();
  TextColumn get iconKey => text().withLength(max: 40).withDefault(const Constant('category'))();
  IntColumn get colorValue => integer()();

  /// Seeded categories cannot be deleted (only archived) so a fresh install
  /// always has a usable set to file transactions under.
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name, kind},
      ];
}

@TableIndex(name: 'idx_payment_methods_archived', columns: {#isArchived})
@DataClassName('PaymentMethodRow')
class PaymentMethods extends Table {
  @override
  String get tableName => 'payment_methods';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40).unique()();
  TextColumn get iconKey => text().withLength(max: 40).withDefault(const Constant('wallet'))();
  IntColumn get colorValue => integer()();

  /// Balance the account already held before tracking started.
  IntColumn get openingBalanceMinor => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

@TableIndex(name: 'idx_tx_date', columns: {#date})
@TableIndex(name: 'idx_tx_type_date', columns: {#type, #date})
@TableIndex(name: 'idx_tx_category', columns: {#categoryId})
@TableIndex(name: 'idx_tx_goal', columns: {#goalId})
@DataClassName('TransactionRow')
class Transactions extends Table {
  @override
  String get tableName => 'transactions';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<TransactionType>()();

  /// Always stored as a positive number of minor units; [type] carries the
  /// direction. That keeps every aggregate a plain SUM.
  IntColumn get amountMinor => integer()();

  IntColumn get categoryId => integer()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.setNull)();

  /// Source account. For a transfer this is the "from" side.
  @ReferenceName('outgoingTransactions')
  IntColumn get paymentMethodId => integer()
      .nullable()
      .references(PaymentMethods, #id, onDelete: KeyAction.setNull)();

  /// Destination account - transfers only.
  @ReferenceName('incomingTransactions')
  IntColumn get toPaymentMethodId => integer()
      .nullable()
      .references(PaymentMethods, #id, onDelete: KeyAction.setNull)();

  /// A savings transaction may be earmarked for a goal; goal progress is
  /// derived from these rows so there is only ever one copy of the number.
  IntColumn get goalId => integer()
      .nullable()
      .references(SavingsGoals, #id, onDelete: KeyAction.setNull)();

  DateTimeColumn get date => dateTime()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().withLength(max: 500).nullable()();
  TextColumn get notes => text().withLength(max: 2000).nullable()();
  TextColumn get currencyCode => text().withLength(max: 8).withDefault(const Constant('INR'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@TableIndex(name: 'idx_budgets_period', columns: {#year, #month})
@DataClassName('BudgetRow')
class Budgets extends Table {
  @override
  String get tableName => 'budgets';

  IntColumn get id => integer().autoIncrement()();

  /// `null` means an overall budget for the whole month.
  IntColumn get categoryId => integer()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.cascade)();

  IntColumn get amountMinor => integer()();

  /// Anchor of the financial month this budget applies to.
  IntColumn get year => integer()();
  IntColumn get month => integer()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('SavingsGoalRow')
class SavingsGoals extends Table {
  @override
  String get tableName => 'savings_goals';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get targetMinor => integer()();

  /// Money already put aside before the goal was created in the app.
  IntColumn get openingMinor => integer().withDefault(const Constant(0))();

  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get iconKey => text().withLength(max: 40).withDefault(const Constant('goal'))();
  IntColumn get colorValue => integer()();
  TextColumn get note => text().withLength(max: 500).nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Simple key/value store for user preferences.
///
/// Settings live in the database rather than SharedPreferences so that a JSON
/// backup captures the complete application state in one atomic snapshot.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  @override
  String get tableName => 'app_settings';

  TextColumn get key => text().withLength(min: 1, max: 60)();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
