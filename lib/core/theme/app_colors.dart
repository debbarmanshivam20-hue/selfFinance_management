import 'package:flutter/material.dart';

/// Finance-specific colours that Material's [ColorScheme] has no slot for.
///
/// Exposed as a [ThemeExtension] so widgets read them from the theme
/// (`context.finance.income`) instead of hard-coding hex values.
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.incomeSoft,
    required this.expense,
    required this.expenseSoft,
    required this.savings,
    required this.savingsSoft,
    required this.transfer,
    required this.transferSoft,
    required this.positive,
    required this.warning,
    required this.critical,
    required this.canvas,
    required this.card,
    required this.cardElevated,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.brandGradient,
    required this.chartSeries,
    required this.shadow,
  });

  final Color income;
  final Color incomeSoft;
  final Color expense;
  final Color expenseSoft;
  final Color savings;
  final Color savingsSoft;
  final Color transfer;
  final Color transferSoft;

  /// Generic "good" colour for deltas that are not tied to a transaction type.
  final Color positive;
  final Color warning;
  final Color critical;

  /// Page background.
  final Color canvas;

  /// Default card fill.
  final Color card;

  /// Raised surfaces (sheets, menus, selected states).
  final Color cardElevated;

  /// 1px separators and card borders.
  final Color hairline;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Brand gradient used on the hero balance card and the add button.
  final List<Color> brandGradient;

  /// Qualitative palette for charts with many series (categories).
  final List<Color> chartSeries;

  final Color shadow;

  Color forSeries(int index) => chartSeries[index % chartSeries.length];

  @override
  FinanceColors copyWith({
    Color? income,
    Color? incomeSoft,
    Color? expense,
    Color? expenseSoft,
    Color? savings,
    Color? savingsSoft,
    Color? transfer,
    Color? transferSoft,
    Color? positive,
    Color? warning,
    Color? critical,
    Color? canvas,
    Color? card,
    Color? cardElevated,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    List<Color>? brandGradient,
    List<Color>? chartSeries,
    Color? shadow,
  }) {
    return FinanceColors(
      income: income ?? this.income,
      incomeSoft: incomeSoft ?? this.incomeSoft,
      expense: expense ?? this.expense,
      expenseSoft: expenseSoft ?? this.expenseSoft,
      savings: savings ?? this.savings,
      savingsSoft: savingsSoft ?? this.savingsSoft,
      transfer: transfer ?? this.transfer,
      transferSoft: transferSoft ?? this.transferSoft,
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      critical: critical ?? this.critical,
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      cardElevated: cardElevated ?? this.cardElevated,
      hairline: hairline ?? this.hairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      brandGradient: brandGradient ?? this.brandGradient,
      chartSeries: chartSeries ?? this.chartSeries,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    List<Color> lerpList(List<Color> a, List<Color> b) => List.generate(
          a.length,
          (i) => Color.lerp(a[i], b[i % b.length], t) ?? a[i],
        );
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      incomeSoft: Color.lerp(incomeSoft, other.incomeSoft, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseSoft: Color.lerp(expenseSoft, other.expenseSoft, t)!,
      savings: Color.lerp(savings, other.savings, t)!,
      savingsSoft: Color.lerp(savingsSoft, other.savingsSoft, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      transferSoft: Color.lerp(transferSoft, other.transferSoft, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      brandGradient: lerpList(brandGradient, other.brandGradient),
      chartSeries: lerpList(chartSeries, other.chartSeries),
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }

  static const FinanceColors dark = FinanceColors(
    income: Color(0xFF34D399),
    incomeSoft: Color(0xFF15302A),
    expense: Color(0xFFFB7185),
    expenseSoft: Color(0xFF351A24),
    savings: Color(0xFF38BDF8),
    savingsSoft: Color(0xFF13293C),
    transfer: Color(0xFFA78BFA),
    transferSoft: Color(0xFF241F3D),
    positive: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    critical: Color(0xFFF87171),
    canvas: Color(0xFF0B0F14),
    card: Color(0xFF141A22),
    cardElevated: Color(0xFF1B232E),
    hairline: Color(0xFF243040),
    textPrimary: Color(0xFFE9F0F7),
    textSecondary: Color(0xFF9AA9BC),
    textTertiary: Color(0xFF6B7A8F),
    brandGradient: <Color>[Color(0xFF10B981), Color(0xFF047857)],
    chartSeries: <Color>[
      Color(0xFF34D399),
      Color(0xFF38BDF8),
      Color(0xFFA78BFA),
      Color(0xFFFBBF24),
      Color(0xFFFB7185),
      Color(0xFF2DD4BF),
      Color(0xFFF472B6),
      Color(0xFF60A5FA),
      Color(0xFFFB923C),
      Color(0xFFA3E635),
    ],
    shadow: Color(0x66000000),
  );

  static const FinanceColors light = FinanceColors(
    income: Color(0xFF059669),
    incomeSoft: Color(0xFFDCFCE7),
    expense: Color(0xFFE11D48),
    expenseSoft: Color(0xFFFFE4E6),
    savings: Color(0xFF0284C7),
    savingsSoft: Color(0xFFE0F2FE),
    transfer: Color(0xFF7C3AED),
    transferSoft: Color(0xFFEDE9FE),
    positive: Color(0xFF059669),
    warning: Color(0xFFD97706),
    critical: Color(0xFFDC2626),
    canvas: Color(0xFFF5F7FA),
    card: Color(0xFFFFFFFF),
    cardElevated: Color(0xFFFFFFFF),
    hairline: Color(0xFFE3E8EF),
    textPrimary: Color(0xFF0B1420),
    textSecondary: Color(0xFF52627A),
    textTertiary: Color(0xFF8A99AD),
    brandGradient: <Color>[Color(0xFF10B981), Color(0xFF047857)],
    chartSeries: <Color>[
      Color(0xFF059669),
      Color(0xFF0284C7),
      Color(0xFF7C3AED),
      Color(0xFFD97706),
      Color(0xFFE11D48),
      Color(0xFF0D9488),
      Color(0xFFDB2777),
      Color(0xFF2563EB),
      Color(0xFFEA580C),
      Color(0xFF65A30D),
    ],
    shadow: Color(0x141B2A44),
  );
}

/// `context.finance` shorthand.
extension FinanceColorsX on BuildContext {
  FinanceColors get finance =>
      Theme.of(this).extension<FinanceColors>() ?? FinanceColors.dark;
}
