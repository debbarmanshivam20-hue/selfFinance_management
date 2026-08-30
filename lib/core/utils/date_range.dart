import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// A half-open date interval `[start, end)`.
///
/// Half-open avoids the classic "last second of the month" bug: a transaction
/// stamped 23:59:59.999 on the final day is still inside the range.
@immutable
class DateRange {
  final DateTime start;
  final DateTime end;
  final String label;

  const DateRange({required this.start, required this.end, this.label = ''});

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(end);

  /// Number of whole days spanned, at least 1.
  int get dayCount {
    final days = end.difference(start).inDays;
    return days <= 0 ? 1 : days;
  }

  /// Every day boundary in the range, oldest first.
  List<DateTime> get days {
    final result = <DateTime>[];
    var cursor = DateTime(start.year, start.month, start.day);
    while (cursor.isBefore(end)) {
      result.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return result;
  }

  DateRange withLabel(String value) =>
      DateRange(start: start, end: end, label: value);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($start -> $end)';
}

/// Builds the financial periods the whole app reports against.
///
/// [monthStartDay] lets a user whose salary lands on the 5th treat "this
/// month" as 5th -> 4th. With the default of 1 this behaves exactly like the
/// calendar month.
@immutable
class FinancialCalendar {
  final int monthStartDay;

  const FinancialCalendar({this.monthStartDay = 1});

  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _shortMonth = DateFormat('MMM');
  static final DateFormat _dayMonth = DateFormat('d MMM');

  int get _clampedStartDay => monthStartDay.clamp(1, 28);

  DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day + 1);

  DateRange day(DateTime date) => DateRange(
        start: startOfDay(date),
        end: endOfDay(date),
        label: _dayMonth.format(date),
      );

  /// Week containing [date], Monday-first.
  DateRange week(DateTime date) {
    final start = startOfDay(date).subtract(Duration(days: date.weekday - 1));
    return DateRange(
      start: start,
      end: DateTime(start.year, start.month, start.day + 7),
      label: 'This week',
    );
  }

  /// The financial month containing [date].
  DateRange month(DateTime date) {
    final startDay = _clampedStartDay;
    final anchor = date.day >= startDay
        ? DateTime(date.year, date.month, startDay)
        : DateTime(date.year, date.month - 1, startDay);
    final next = DateTime(anchor.year, anchor.month + 1, startDay);
    return DateRange(start: anchor, end: next, label: monthLabel(anchor));
  }

  /// The financial month anchored at [year]-[month] (1-12).
  DateRange monthOf(int year, int month) {
    final anchor = DateTime(year, month, _clampedStartDay);
    return DateRange(
      start: anchor,
      end: DateTime(year, month + 1, _clampedStartDay),
      label: monthLabel(anchor),
    );
  }

  DateRange previousMonth(DateTime date) {
    final current = month(date);
    return monthOf(current.start.year, current.start.month - 1);
  }

  DateRange nextMonth(DateTime date) {
    final current = month(date);
    return monthOf(current.start.year, current.start.month + 1);
  }

  /// The financial year starting at the first financial month of [year].
  DateRange year(int year) => DateRange(
        start: DateTime(year, 1, _clampedStartDay),
        end: DateTime(year + 1, 1, _clampedStartDay),
        label: '$year',
      );

  DateRange yearOfDate(DateTime date) => year(month(date).start.year);

  /// The 12 financial months of [year], January-anchored first.
  List<DateRange> monthsOfYear(int year) =>
      List.generate(12, (index) => monthOf(year, index + 1));

  /// The last [count] financial months ending with the one containing [date].
  List<DateRange> trailingMonths(DateTime date, int count) {
    final current = month(date);
    return List.generate(
      count,
      (i) => monthOf(current.start.year, current.start.month - (count - 1 - i)),
    );
  }

  /// Which financial month a transaction dated [date] belongs to, expressed as
  /// the anchor year/month pair used by budgets.
  ({int year, int month}) periodKey(DateTime date) {
    final range = month(date);
    return (year: range.start.year, month: range.start.month);
  }

  String monthLabel(DateTime anchor) => _monthYear.format(anchor);

  String shortMonthLabel(DateTime anchor) => _shortMonth.format(anchor);

  @override
  bool operator ==(Object other) =>
      other is FinancialCalendar && other.monthStartDay == monthStartDay;

  @override
  int get hashCode => monthStartDay.hashCode;
}

/// Human friendly date helpers used across the UI.
class DateLabels {
  DateLabels._();

  static final DateFormat full = DateFormat('EEE, d MMM yyyy');
  static final DateFormat medium = DateFormat('d MMM yyyy');
  static final DateFormat short = DateFormat('d MMM');
  static final DateFormat weekday = DateFormat('EEEE');
  static final DateFormat weekdayShort = DateFormat('EEE');
  static final DateFormat time = DateFormat('h:mm a');

  /// "Today", "Yesterday", or a formatted date.
  static String relative(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final a = DateTime(date.year, date.month, date.day);
    final b = DateTime(today.year, today.month, today.day);
    final diff = b.difference(a).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    if (diff > 1 && diff < 7) return weekday.format(date);
    return a.year == b.year ? short.format(date) : medium.format(date);
  }
}
