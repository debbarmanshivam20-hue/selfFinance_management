import 'package:flutter/foundation.dart';

import '../core/utils/date_range.dart';
import 'enums.dart';

/// Everything the transaction list can be narrowed by.
///
/// Held as one immutable value so a single Riverpod provider drives the query,
/// the header summary and the "filters active" badge from the same state.
@immutable
class TransactionFilter {
  const TransactionFilter({
    this.types = const <TransactionType>{},
    this.preset = DatePreset.thisMonth,
    this.customRange,
    this.query = '',
    this.categoryId,
    this.paymentMethodId,
    this.sort = TransactionSort.dateDesc,
  });

  /// Empty means "every type".
  final Set<TransactionType> types;
  final DatePreset preset;
  final DateRange? customRange;
  final String query;
  final int? categoryId;
  final int? paymentMethodId;
  final TransactionSort sort;

  static const TransactionFilter allTime =
      TransactionFilter(preset: DatePreset.all);

  bool get hasTypeFilter => types.isNotEmpty;

  /// Whether anything beyond the default view is applied (drives the badge).
  bool get isNarrowed =>
      types.isNotEmpty ||
      query.trim().isNotEmpty ||
      categoryId != null ||
      paymentMethodId != null ||
      sort != TransactionSort.dateDesc;

  int get activeFilterCount {
    var count = 0;
    if (types.isNotEmpty) count++;
    if (categoryId != null) count++;
    if (paymentMethodId != null) count++;
    if (sort != TransactionSort.dateDesc) count++;
    return count;
  }

  /// Resolves [preset] into a concrete window, or `null` for "all time".
  DateRange? resolveRange(FinancialCalendar calendar, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return switch (preset) {
      DatePreset.all => null,
      DatePreset.today => calendar.day(today),
      DatePreset.thisWeek => calendar.week(today),
      DatePreset.thisMonth => calendar.month(today),
      DatePreset.lastMonth => calendar.previousMonth(today),
      DatePreset.thisYear => calendar.yearOfDate(today),
      DatePreset.custom => customRange,
    };
  }

  TransactionFilter copyWith({
    Set<TransactionType>? types,
    DatePreset? preset,
    DateRange? customRange,
    bool clearCustomRange = false,
    String? query,
    int? categoryId,
    bool clearCategory = false,
    int? paymentMethodId,
    bool clearPaymentMethod = false,
    TransactionSort? sort,
  }) {
    return TransactionFilter(
      types: types ?? this.types,
      preset: preset ?? this.preset,
      customRange: clearCustomRange ? null : (customRange ?? this.customRange),
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      paymentMethodId: clearPaymentMethod
          ? null
          : (paymentMethodId ?? this.paymentMethodId),
      sort: sort ?? this.sort,
    );
  }

  TransactionFilter cleared() => TransactionFilter(preset: preset, query: query);

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      setEquals(other.types, types) &&
      other.preset == preset &&
      other.customRange == customRange &&
      other.query == query &&
      other.categoryId == categoryId &&
      other.paymentMethodId == paymentMethodId &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(types),
        preset,
        customRange,
        query,
        categoryId,
        paymentMethodId,
        sort,
      );
}
