import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/date_range.dart';
import '../core/utils/money.dart';

/// A typed view over the settings key/value table.
///
/// Every getter has a safe fallback, so a missing or corrupted row degrades to
/// the default instead of crashing app start-up.
@immutable
class AppSettingsModel {
  const AppSettingsModel({
    this.themeMode = ThemeMode.system,
    this.currencyCode = 'INR',
    this.monthStartDay = 1,
    this.budgetWarningThreshold = BudgetDefaults.warningThreshold,
    this.budgetCriticalThreshold = BudgetDefaults.criticalThreshold,
    this.onboardingComplete = false,
    this.lastBackupAt,
  });

  final ThemeMode themeMode;
  final String currencyCode;
  final int monthStartDay;
  final double budgetWarningThreshold;
  final double budgetCriticalThreshold;
  final bool onboardingComplete;
  final DateTime? lastBackupAt;

  static const AppSettingsModel defaults = AppSettingsModel();

  CurrencyOption get currency => SupportedCurrencies.byCode(currencyCode);

  MoneyFormatter get formatter => MoneyFormatter(
        symbol: currency.symbol,
        locale: currency.locale,
      );

  FinancialCalendar get calendar =>
      FinancialCalendar(monthStartDay: monthStartDay);

  factory AppSettingsModel.fromMap(Map<String, String> map) {
    return AppSettingsModel(
      themeMode: _parseThemeMode(map[SettingsKeys.themeMode]),
      currencyCode: map[SettingsKeys.currencyCode] ?? 'INR',
      monthStartDay:
          (int.tryParse(map[SettingsKeys.monthStartDay] ?? '') ?? 1).clamp(1, 28),
      budgetWarningThreshold:
          double.tryParse(map[SettingsKeys.budgetWarningThreshold] ?? '') ??
              BudgetDefaults.warningThreshold,
      budgetCriticalThreshold:
          double.tryParse(map[SettingsKeys.budgetCriticalThreshold] ?? '') ??
              BudgetDefaults.criticalThreshold,
      onboardingComplete: map[SettingsKeys.onboardingComplete] == 'true',
      lastBackupAt: DateTime.tryParse(map[SettingsKeys.lastBackupAt] ?? ''),
    );
  }

  Map<String, String> toMap() => <String, String>{
        SettingsKeys.themeMode: themeMode.name,
        SettingsKeys.currencyCode: currencyCode,
        SettingsKeys.monthStartDay: '$monthStartDay',
        SettingsKeys.budgetWarningThreshold: '$budgetWarningThreshold',
        SettingsKeys.budgetCriticalThreshold: '$budgetCriticalThreshold',
        SettingsKeys.onboardingComplete: '$onboardingComplete',
        if (lastBackupAt != null)
          SettingsKeys.lastBackupAt: lastBackupAt!.toIso8601String(),
      };

  static ThemeMode _parseThemeMode(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  @override
  bool operator ==(Object other) =>
      other is AppSettingsModel &&
      other.themeMode == themeMode &&
      other.currencyCode == currencyCode &&
      other.monthStartDay == monthStartDay &&
      other.budgetWarningThreshold == budgetWarningThreshold &&
      other.budgetCriticalThreshold == budgetCriticalThreshold &&
      other.onboardingComplete == onboardingComplete &&
      other.lastBackupAt == lastBackupAt;

  @override
  int get hashCode => Object.hash(
        themeMode,
        currencyCode,
        monthStartDay,
        budgetWarningThreshold,
        budgetCriticalThreshold,
        onboardingComplete,
        lastBackupAt,
      );
}
