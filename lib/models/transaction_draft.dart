import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/errors/failures.dart';
import '../core/utils/money.dart';
import 'enums.dart';

/// A validated candidate transaction on its way into the database.
///
/// Validation lives here rather than in the form widget so the same rules
/// protect the repository, a JSON import and any future entry point.
class TransactionDraft {
  TransactionDraft({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.title,
    this.categoryId,
    this.paymentMethodId,
    this.toPaymentMethodId,
    this.goalId,
    this.description,
    this.notes,
    this.currencyCode = 'INR',
  });

  final int? id;
  final TransactionType type;
  final Money amount;
  final DateTime date;
  final String title;
  final int? categoryId;
  final int? paymentMethodId;
  final int? toPaymentMethodId;
  final int? goalId;
  final String? description;
  final String? notes;
  final String currencyCode;

  bool get isUpdate => id != null;

  /// Throws [AppFailure] with a user-facing message when the draft is invalid.
  void validate() {
    if (amount.minor <= 0) {
      throw const AppFailure.validation('Enter an amount greater than zero.');
    }
    if (amount.minor > 999999999999) {
      throw const AppFailure.validation('That amount is too large to record.');
    }
    if (title.trim().isEmpty) {
      throw const AppFailure.validation('Add a short title for this entry.');
    }
    if (type.requiresCategory && categoryId == null) {
      throw const AppFailure.validation('Choose a category.');
    }
    if (type.requiresDestination) {
      if (paymentMethodId == null || toPaymentMethodId == null) {
        throw const AppFailure.validation(
            'Choose the account to transfer from and to.');
      }
      if (paymentMethodId == toPaymentMethodId) {
        throw const AppFailure.validation(
            'Transfer to a different account than the source.');
      }
    }
    // A date far outside a plausible range is almost always a typo in the
    // year field, and would silently distort every chart.
    final now = DateTime.now();
    if (date.year < 1970 || date.isAfter(DateTime(now.year + 50))) {
      throw const AppFailure.validation('That date does not look right.');
    }
  }

  TransactionsCompanion toCompanion({required DateTime now}) {
    final isTransfer = type == TransactionType.transfer;
    return TransactionsCompanion(
      id: id == null ? const Value.absent() : Value(id!),
      type: Value(type),
      amountMinor: Value(amount.minor),
      categoryId: Value(isTransfer ? null : categoryId),
      paymentMethodId: Value(paymentMethodId),
      toPaymentMethodId: Value(isTransfer ? toPaymentMethodId : null),
      goalId: Value(type == TransactionType.savings ? goalId : null),
      date: Value(date),
      title: Value(title.trim()),
      description: Value(_clean(description)),
      notes: Value(_clean(notes)),
      currencyCode: Value(currencyCode),
      createdAt: id == null ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    );
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static TransactionDraft fromRow(TransactionRow row) => TransactionDraft(
        id: row.id,
        type: row.type,
        amount: Money(row.amountMinor),
        date: row.date,
        title: row.title,
        categoryId: row.categoryId,
        paymentMethodId: row.paymentMethodId,
        toPaymentMethodId: row.toPaymentMethodId,
        goalId: row.goalId,
        description: row.description,
        notes: row.notes,
        currencyCode: row.currencyCode,
      );
}
