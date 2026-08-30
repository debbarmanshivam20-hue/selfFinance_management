/// Application-wide identity and tuning constants.
///
/// Keeping the name here (rather than sprinkled through widgets and the
/// manifest) means rebranding is a one-line change plus a manifest label.
class AppInfo {
  AppInfo._();

  static const String name = 'FinVault';
  static const String tagline = 'Personal Finance';
  static const String version = '1.0.0';
  static const String description =
      'An offline-first personal finance tracker. All of your financial data '
      'stays on this device.';
}

/// Keys used in the `app_settings` table. Centralised so a typo cannot create
/// a silently orphaned setting.
class SettingsKeys {
  SettingsKeys._();

  static const String themeMode = 'theme_mode';
  static const String currencyCode = 'currency_code';
  static const String monthStartDay = 'month_start_day';
  static const String budgetWarningThreshold = 'budget_warning_threshold';
  static const String budgetCriticalThreshold = 'budget_critical_threshold';
  static const String onboardingComplete = 'onboarding_complete';
  static const String lastBackupAt = 'last_backup_at';
  static const String schemaSeededAt = 'schema_seeded_at';
}

/// Currencies the formatter understands. INR is the default; adding another
/// entry here is all that is needed to support it.
class CurrencyOption {
  final String code;
  final String symbol;
  final String name;
  final String locale;

  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.name,
    required this.locale,
  });
}

class SupportedCurrencies {
  SupportedCurrencies._();

  static const CurrencyOption inr = CurrencyOption(
    code: 'INR',
    symbol: '₹',
    name: 'Indian Rupee',
    locale: 'en_IN',
  );

  static const List<CurrencyOption> all = <CurrencyOption>[
    inr,
    CurrencyOption(code: 'USD', symbol: '\$', name: 'US Dollar', locale: 'en_US'),
    CurrencyOption(code: 'EUR', symbol: '€', name: 'Euro', locale: 'en_IE'),
    CurrencyOption(code: 'GBP', symbol: '£', name: 'British Pound', locale: 'en_GB'),
    CurrencyOption(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham', locale: 'en_AE'),
    CurrencyOption(code: 'JPY', symbol: '¥', name: 'Japanese Yen', locale: 'ja_JP'),
    CurrencyOption(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', locale: 'en_AU'),
    CurrencyOption(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', locale: 'en_CA'),
    CurrencyOption(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', locale: 'en_SG'),
  ];

  static CurrencyOption byCode(String? code) => all.firstWhere(
        (currency) => currency.code == code,
        orElse: () => inr,
      );
}

/// Defaults for budget usage colouring. Stored in settings so they are already
/// configurable rather than hard-coded at the call site.
class BudgetDefaults {
  BudgetDefaults._();

  static const double warningThreshold = 70;
  static const double criticalThreshold = 90;
}
