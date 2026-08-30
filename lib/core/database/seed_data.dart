import 'package:drift/drift.dart';

import '../../models/enums.dart';
import '../constants/app_constants.dart';
import 'app_database.dart';

/// The starter data a brand new install begins with.
///
/// Seeding happens once, inside the same transaction that creates the schema,
/// so the app can never open with an empty category list.
class SeedData {
  SeedData._();

  static List<CategoriesCompanion> categories(DateTime now) {
    final rows = <CategoriesCompanion>[];
    var order = 0;

    void add(String name, CategoryKind kind, String iconKey, int color) {
      rows.add(CategoriesCompanion.insert(
        name: name,
        kind: kind,
        colorValue: color,
        createdAt: now,
        iconKey: Value(iconKey),
        isSystem: const Value(true),
        sortOrder: Value(order++),
      ));
    }

    // Income ---------------------------------------------------------------
    add('Salary', CategoryKind.income, 'salary', 0xFF10B981);
    add('Freelancing', CategoryKind.income, 'freelance', 0xFF14B8A6);
    add('Business', CategoryKind.income, 'business', 0xFF22C55E);
    add('Bonus', CategoryKind.income, 'bonus', 0xFFEAB308);
    add('Interest', CategoryKind.income, 'interest', 0xFF06B6D4);
    add('Investment', CategoryKind.income, 'investment', 0xFF3B82F6);
    add('Other', CategoryKind.income, 'more', 0xFF64748B);

    // Expense --------------------------------------------------------------
    order = 0;
    add('Food', CategoryKind.expense, 'restaurant', 0xFFF97316);
    add('Groceries', CategoryKind.expense, 'groceries', 0xFF84CC16);
    add('Transport', CategoryKind.expense, 'transport', 0xFF06B6D4);
    add('Shopping', CategoryKind.expense, 'shopping', 0xFFEC4899);
    add('Bills', CategoryKind.expense, 'bills', 0xFF3B82F6);
    add('Rent', CategoryKind.expense, 'rent', 0xFF8B5CF6);
    add('Entertainment', CategoryKind.expense, 'entertainment', 0xFFA855F7);
    add('Health', CategoryKind.expense, 'health', 0xFFF43F5E);
    add('Education', CategoryKind.expense, 'education', 0xFF6366F1);
    add('Travel', CategoryKind.expense, 'travel', 0xFF14B8A6);
    add('EMI', CategoryKind.expense, 'emi', 0xFFEF4444);
    add('Subscriptions', CategoryKind.expense, 'subscriptions', 0xFFF59E0B);
    add('Utilities', CategoryKind.expense, 'utilities', 0xFF22C55E);
    add('Other', CategoryKind.expense, 'more', 0xFF64748B);

    // Savings --------------------------------------------------------------
    order = 0;
    add('General Savings', CategoryKind.savings, 'savings', 0xFF38BDF8);
    add('Emergency Fund', CategoryKind.savings, 'emergency', 0xFF0EA5E9);
    add('Investment', CategoryKind.savings, 'investment', 0xFF6366F1);
    add('Retirement', CategoryKind.savings, 'retirement', 0xFF8B5CF6);
    add('Goal Contribution', CategoryKind.savings, 'goal', 0xFF14B8A6);
    add('Other', CategoryKind.savings, 'more', 0xFF64748B);

    return rows;
  }

  static List<PaymentMethodsCompanion> paymentMethods(DateTime now) {
    var order = 0;
    PaymentMethodsCompanion make(String name, String iconKey, int color) {
      return PaymentMethodsCompanion.insert(
        name: name,
        colorValue: color,
        createdAt: now,
        iconKey: Value(iconKey),
        isSystem: const Value(true),
        sortOrder: Value(order++),
      );
    }

    return <PaymentMethodsCompanion>[
      make('Cash', 'cash', 0xFF22C55E),
      make('Bank', 'bank', 0xFF3B82F6),
      make('UPI', 'upi', 0xFF8B5CF6),
      make('Credit Card', 'credit_card', 0xFFF43F5E),
      make('Debit Card', 'debit_card', 0xFF06B6D4),
      make('Other', 'wallet', 0xFF64748B),
    ];
  }

  static Map<String, String> settings(DateTime now) => <String, String>{
        SettingsKeys.themeMode: 'system',
        SettingsKeys.currencyCode: SupportedCurrencies.inr.code,
        SettingsKeys.monthStartDay: '1',
        SettingsKeys.budgetWarningThreshold:
            BudgetDefaults.warningThreshold.toString(),
        SettingsKeys.budgetCriticalThreshold:
            BudgetDefaults.criticalThreshold.toString(),
        SettingsKeys.onboardingComplete: 'false',
        SettingsKeys.schemaSeededAt: now.toIso8601String(),
      };
}
