import 'package:flutter/material.dart';

import '../core/constants/app_icons.dart';
import '../core/database/app_database.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/money.dart';
import 'enums.dart';

/// A transaction together with the rows it points at.
///
/// The UI needs the category name and account names on every row; resolving
/// them once in the repository (via a join) avoids an N+1 lookup per list item.
@immutable
class TransactionView {
  const TransactionView({
    required this.row,
    this.category,
    this.source,
    this.destination,
    this.goal,
  });

  final TransactionRow row;
  final CategoryRow? category;
  final PaymentMethodRow? source;
  final PaymentMethodRow? destination;
  final SavingsGoalRow? goal;

  int get id => row.id;
  TransactionType get type => row.type;
  Money get amount => Money(row.amountMinor);
  DateTime get date => row.date;
  String get title => row.title;
  String? get notes => row.notes;
  String? get description => row.description;

  /// A category may have been deleted after the transaction was filed.
  String get categoryName => category?.name ?? 'Uncategorised';

  String get accountName => source?.name ?? 'Unspecified';

  /// "Bank -> Cash" for transfers, otherwise the single account.
  String get accountLabel => type == TransactionType.transfer
      ? '${source?.name ?? '?'} → ${destination?.name ?? '?'}'
      : accountName;

  IconData get icon => type == TransactionType.transfer
      ? AppIcons.resolve('transfer')
      : AppIcons.resolve(category?.iconKey);

  /// Falls back to the type colour when the category is gone.
  Color accentColor(FinanceColors palette) {
    if (type == TransactionType.transfer) return palette.transfer;
    final value = category?.colorValue;
    if (value != null) return Color(value);
    return switch (type) {
      TransactionType.income => palette.income,
      TransactionType.expense => palette.expense,
      TransactionType.savings => palette.savings,
      TransactionType.transfer => palette.transfer,
    };
  }

  Color typeColor(FinanceColors palette) => switch (type) {
        TransactionType.income => palette.income,
        TransactionType.expense => palette.expense,
        TransactionType.savings => palette.savings,
        TransactionType.transfer => palette.transfer,
      };

  /// The text a search query is matched against.
  String get searchHaystack => <String?>[
        title,
        description,
        notes,
        category?.name,
        source?.name,
        destination?.name,
        goal?.name,
      ].whereType<String>().join(' ').toLowerCase();
}
