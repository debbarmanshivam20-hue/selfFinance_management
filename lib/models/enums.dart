import 'package:flutter/material.dart';

/// The four kinds of money movement the app understands.
///
/// Stored in SQLite as the enum *name* (`'income'`, `'expense'`, ...) rather
/// than its index, so reordering this enum can never silently reinterpret
/// existing rows, and JSON backups stay human readable.
enum TransactionType {
  income,
  expense,
  savings,
  transfer;

  String get label => switch (this) {
        TransactionType.income => 'Income',
        TransactionType.expense => 'Expense',
        TransactionType.savings => 'Savings',
        TransactionType.transfer => 'Transfer',
      };

  IconData get icon => switch (this) {
        TransactionType.income => Icons.south_west_rounded,
        TransactionType.expense => Icons.north_east_rounded,
        TransactionType.savings => Icons.savings_rounded,
        TransactionType.transfer => Icons.swap_horiz_rounded,
      };

  /// `+` for money coming in, `-` for money going out, `` for transfers
  /// (a transfer changes neither net worth nor spending).
  String get sign => switch (this) {
        TransactionType.income => '+',
        TransactionType.expense => '-',
        TransactionType.savings => '-',
        TransactionType.transfer => '',
      };

  /// Whether a transaction of this type must be filed under a category.
  bool get requiresCategory => this != TransactionType.transfer;

  /// Whether this type moves money between two payment methods.
  bool get requiresDestination => this == TransactionType.transfer;

  static TransactionType? tryParse(String? value) {
    for (final type in TransactionType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

/// Which transaction types a category may be used for.
enum CategoryKind {
  income,
  expense,
  savings;

  String get label => switch (this) {
        CategoryKind.income => 'Income',
        CategoryKind.expense => 'Expense',
        CategoryKind.savings => 'Savings',
      };

  TransactionType get transactionType => switch (this) {
        CategoryKind.income => TransactionType.income,
        CategoryKind.expense => TransactionType.expense,
        CategoryKind.savings => TransactionType.savings,
      };

  static CategoryKind? forTransactionType(TransactionType type) =>
      switch (type) {
        TransactionType.income => CategoryKind.income,
        TransactionType.expense => CategoryKind.expense,
        TransactionType.savings => CategoryKind.savings,
        TransactionType.transfer => null,
      };

  static CategoryKind? tryParse(String? value) {
    for (final kind in CategoryKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}

/// How a list of transactions is ordered.
enum TransactionSort {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc,
  titleAsc;

  String get label => switch (this) {
        TransactionSort.dateDesc => 'Newest first',
        TransactionSort.dateAsc => 'Oldest first',
        TransactionSort.amountDesc => 'Highest amount',
        TransactionSort.amountAsc => 'Lowest amount',
        TransactionSort.titleAsc => 'Title (A-Z)',
      };
}

/// Preset windows offered by the transaction and analytics filters.
enum DatePreset {
  all,
  today,
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
  custom;

  String get label => switch (this) {
        DatePreset.all => 'All time',
        DatePreset.today => 'Today',
        DatePreset.thisWeek => 'This week',
        DatePreset.thisMonth => 'This month',
        DatePreset.lastMonth => 'Last month',
        DatePreset.thisYear => 'This year',
        DatePreset.custom => 'Custom range',
      };
}
