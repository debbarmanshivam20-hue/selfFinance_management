import 'package:intl/intl.dart';

/// An exact monetary amount.
///
/// Money is stored as a whole number of *minor units* (paise for INR, cents for
/// USD, ...). Binary floating point cannot represent values like `0.1`
/// exactly, so every addition of `10.10` would accumulate error. Integers make
/// addition, subtraction and comparison exact; only division (percentages,
/// averages) is approximate, and that is done deliberately and explicitly.
class Money implements Comparable<Money> {
  /// The amount in minor units (e.g. 12345 == ₹123.45).
  final int minor;

  const Money(this.minor);

  static const Money zero = Money(0);

  /// Builds an amount from a major-unit value (e.g. `Money.fromMajor(123.45)`).
  ///
  /// Rounds half-away-from-zero so `2.345` -> `234` never silently truncates.
  factory Money.fromMajor(num major, {int decimals = 2}) {
    final factor = _pow10(decimals);
    return Money((major * factor).round());
  }

  /// Parses user input such as `"1,234.56"`, `"1234"`, `"₹ 1 234,00"`.
  ///
  /// Parsing is done on the digit groups rather than via [double.parse] so no
  /// floating point rounding can creep into a stored amount. Returns `null`
  /// when the text is not a valid non-negative amount.
  static Money? tryParse(String input, {int decimals = 2}) {
    var text = input.trim();
    if (text.isEmpty) return null;

    var negative = false;
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1).trim();
    }

    // Strip anything that is not a digit or a decimal separator.
    text = text.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (text.isEmpty) return null;

    // The last separator that is followed by 1-2 digits is the decimal point;
    // every other separator is a grouping separator.
    String whole;
    String fraction = '';
    final match = RegExp(r'^(.*)[.,](\d{1,' '$decimals' r'})$').firstMatch(text);
    if (match != null) {
      whole = match.group(1)!;
      fraction = match.group(2)!;
    } else {
      whole = text;
    }

    whole = whole.replaceAll(RegExp(r'[.,]'), '');
    if (whole.isEmpty) whole = '0';
    if (!RegExp(r'^\d+$').hasMatch(whole)) return null;

    fraction = fraction.padRight(decimals, '0');

    final wholeValue = int.tryParse(whole);
    final fractionValue = decimals == 0 ? 0 : int.tryParse(fraction);
    if (wholeValue == null || fractionValue == null) return null;

    final total = wholeValue * _pow10(decimals) + fractionValue;
    return Money(negative ? -total : total);
  }

  static int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  /// The value in major units. Only use for display / charting, never to store
  /// or accumulate money.
  double get asDouble => minor / 100.0;

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  Money operator +(Money other) => Money(minor + other.minor);
  Money operator -(Money other) => Money(minor - other.minor);
  Money operator -() => Money(-minor);
  Money operator *(int factor) => Money(minor * factor);

  bool operator >(Money other) => minor > other.minor;
  bool operator >=(Money other) => minor >= other.minor;
  bool operator <(Money other) => minor < other.minor;
  bool operator <=(Money other) => minor <= other.minor;

  Money get abs => Money(minor.abs());

  /// Splits this amount into [parts], distributing the remainder so the parts
  /// always add back up to exactly this amount.
  List<Money> allocate(int parts) {
    if (parts <= 0) return const [];
    final base = minor ~/ parts;
    var remainder = minor - base * parts;
    return List.generate(parts, (i) {
      var value = base;
      if (remainder > 0) {
        value += 1;
        remainder -= 1;
      } else if (remainder < 0) {
        value -= 1;
        remainder += 1;
      }
      return Money(value);
    });
  }

  /// `this / other` as a percentage, or `null` when [other] is zero.
  ///
  /// Ratios are inherently fractional, so this returns a double - but it is
  /// derived from exact integers, and is never fed back into stored amounts.
  double? percentOf(Money other) {
    if (other.minor == 0) return null;
    return minor * 100 / other.minor;
  }

  static Money sum(Iterable<Money> values) {
    var total = 0;
    for (final value in values) {
      total += value.minor;
    }
    return Money(total);
  }

  @override
  int compareTo(Money other) => minor.compareTo(other.minor);

  @override
  bool operator ==(Object other) => other is Money && other.minor == minor;

  @override
  int get hashCode => minor.hashCode;

  @override
  String toString() => 'Money($minor)';
}

/// Formats [Money] for display. Currency is configurable so the app can
/// support more than INR later without touching call sites.
class MoneyFormatter {
  const MoneyFormatter({
    this.symbol = '₹',
    this.locale = 'en_IN',
    this.decimals = 2,
  });

  final String symbol;
  final String locale;
  final int decimals;

  /// e.g. `₹1,23,456.00`
  String format(Money money, {bool showDecimals = true, bool signed = false}) {
    final format = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: showDecimals ? decimals : 0,
    );
    final text = format.format(money.abs.asDouble);
    if (signed && !money.isZero) return '${money.isNegative ? '-' : '+'}$text';
    return money.isNegative ? '-$text' : text;
  }

  /// e.g. `₹1.2L`, `₹45.3K` - used where space is tight (chart axes, chips).
  String compact(Money money) {
    final value = money.abs.asDouble;
    final sign = money.isNegative ? '-' : '';
    String body;
    if (value >= 10000000) {
      body = '${(value / 10000000).toStringAsFixed(value >= 100000000 ? 0 : 1)}Cr';
    } else if (value >= 100000) {
      body = '${(value / 100000).toStringAsFixed(value >= 1000000 ? 0 : 1)}L';
    } else if (value >= 1000) {
      body = '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    } else {
      body = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
    }
    return '$sign$symbol$body';
  }

  /// Plain grouped digits without a currency symbol (used inside text fields).
  String plain(Money money) =>
      NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: decimals)
          .format(money.asDouble);
}
