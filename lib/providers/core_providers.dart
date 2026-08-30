import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/database/app_database.dart';
import '../core/utils/date_range.dart';
import '../core/utils/money.dart';
import '../models/app_settings_model.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/payment_method_repository.dart';
import '../repositories/savings_goal_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/backup_service.dart';
import '../services/insights_service.dart';

/// The opened database. Overridden in `main()` once initialisation succeeds,
/// so nothing can read it before the schema exists.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('databaseProvider must be overridden at start-up');
});

/// The settings loaded synchronously during start-up. Overridden in `main()`.
final initialSettingsProvider = Provider<AppSettingsModel>((ref) {
  return AppSettingsModel.defaults;
});

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final paymentMethodRepositoryProvider = Provider<PaymentMethodRepository>(
  (ref) => PaymentMethodRepository(ref.watch(databaseProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(databaseProvider)),
);

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>(
  (ref) => SavingsGoalRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

final insightsServiceProvider =
    Provider<InsightsService>((ref) => const InsightsService());

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

/// Settings exposed synchronously.
///
/// The first value is read before the first frame, then the notifier keeps
/// itself in sync with the database. That means no widget has to unwrap an
/// `AsyncValue` just to know which currency symbol to draw.
class SettingsController extends Notifier<AppSettingsModel> {
  @override
  AppSettingsModel build() {
    final repository = ref.watch(settingsRepositoryProvider);
    final subscription = repository.watch().listen((value) => state = value);
    ref.onDispose(subscription.cancel);
    return ref.read(initialSettingsProvider);
  }

  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  Future<void> setThemeMode(ThemeMode mode) =>
      _repository.put(SettingsKeys.themeMode, mode.name);

  Future<void> setCurrency(String code) =>
      _repository.put(SettingsKeys.currencyCode, code);

  Future<void> setMonthStartDay(int day) =>
      _repository.put(SettingsKeys.monthStartDay, '${day.clamp(1, 28)}');

  Future<void> setBudgetThresholds({
    required double warning,
    required double critical,
  }) async {
    await _repository.putAll(<String, String>{
      SettingsKeys.budgetWarningThreshold: '${warning.clamp(1, 100)}',
      SettingsKeys.budgetCriticalThreshold: '${critical.clamp(1, 100)}',
    });
  }

  Future<void> completeOnboarding() =>
      _repository.put(SettingsKeys.onboardingComplete, 'true');
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettingsModel>(
        SettingsController.new);

/// Financial calendar derived from the user's month-start preference.
final calendarProvider = Provider<FinancialCalendar>(
  (ref) => ref.watch(settingsProvider.select((s) => s.calendar)),
);

/// Currency formatter derived from the selected currency.
final moneyFormatterProvider = Provider<MoneyFormatter>(
  (ref) => ref.watch(settingsProvider.select((s) => s.formatter)),
);

/// "Now", captured once so every card in a frame agrees on the date.
///
/// Invalidated when the app returns to the foreground so a session left open
/// overnight does not keep reporting yesterday as "today".
final nowProvider = Provider<DateTime>((ref) => DateTime.now());

// ---------------------------------------------------------------------------
// Common windows
// ---------------------------------------------------------------------------

final todayRangeProvider = Provider<DateRange>(
  (ref) => ref.watch(calendarProvider).day(ref.watch(nowProvider)),
);

final thisWeekRangeProvider = Provider<DateRange>(
  (ref) => ref.watch(calendarProvider).week(ref.watch(nowProvider)),
);

final thisMonthRangeProvider = Provider<DateRange>(
  (ref) => ref.watch(calendarProvider).month(ref.watch(nowProvider)),
);

final lastMonthRangeProvider = Provider<DateRange>(
  (ref) => ref.watch(calendarProvider).previousMonth(ref.watch(nowProvider)),
);

final thisYearRangeProvider = Provider<DateRange>(
  (ref) => ref.watch(calendarProvider).yearOfDate(ref.watch(nowProvider)),
);

// ---------------------------------------------------------------------------
// AsyncValue plumbing
// ---------------------------------------------------------------------------

/// Combines several async sources into one.
///
/// Returns the first error if any source failed, loading while any source is
/// still waiting, and otherwise the value produced by [build].
AsyncValue<R> combineAsync<R>(
  List<AsyncValue<dynamic>> sources,
  R Function() build,
) {
  for (final source in sources) {
    final error = source.error;
    if (error != null) {
      return AsyncValue.error(error, source.stackTrace ?? StackTrace.current);
    }
  }
  for (final source in sources) {
    if (!source.hasValue) return const AsyncValue.loading();
  }
  return AsyncValue<R>.data(build());
}
