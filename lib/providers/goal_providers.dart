import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';
import '../models/analytics.dart';
import '../services/finance_calculator.dart';
import 'core_providers.dart';

final savingsGoalsProvider = StreamProvider<List<SavingsGoalRow>>((ref) {
  return ref.watch(savingsGoalRepositoryProvider).watchAll();
});

final allSavingsGoalsProvider = StreamProvider<List<SavingsGoalRow>>((ref) {
  return ref
      .watch(savingsGoalRepositoryProvider)
      .watchAll(includeArchived: true);
});

/// Money contributed to each goal, summed from savings transactions.
final goalContributionsProvider = StreamProvider<
    Map<int, ({Money total, int count, DateTime? last})>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchGoalContributions();
});

/// Goals joined with their progress.
final goalProgressProvider = Provider<AsyncValue<List<GoalProgress>>>((ref) {
  final goals = ref.watch(savingsGoalsProvider);
  final contributions = ref.watch(goalContributionsProvider);

  return combineAsync<List<GoalProgress>>(
    [goals, contributions],
    () => FinanceCalculator.buildGoalProgress(
      goals: goals.requireValue,
      contributions: contributions.requireValue,
    ),
  );
});

final goalProgressByIdProvider =
    Provider.family<AsyncValue<GoalProgress?>, int>((ref, id) {
  final progress = ref.watch(goalProgressProvider);
  return progress.whenData(
    (list) => list.where((item) => item.goal.id == id).firstOrNull,
  );
});

/// Writes, wrapped so screens get a single object to call.
class GoalActions {
  const GoalActions(this._ref);

  final Ref _ref;

  Future<int> create({
    required String name,
    required Money target,
    Money opening = Money.zero,
    DateTime? targetDate,
    String iconKey = 'goal',
    required int colorValue,
    String? note,
  }) =>
      _ref.read(savingsGoalRepositoryProvider).create(
            name: name,
            target: target,
            opening: opening,
            targetDate: targetDate,
            iconKey: iconKey,
            colorValue: colorValue,
            note: note,
          );

  Future<void> update(
    int id, {
    required String name,
    required Money target,
    required Money opening,
    DateTime? targetDate,
    bool clearTargetDate = false,
    required String iconKey,
    required int colorValue,
    String? note,
  }) =>
      _ref.read(savingsGoalRepositoryProvider).updateGoal(
            id,
            name: name,
            target: target,
            opening: opening,
            targetDate: targetDate,
            clearTargetDate: clearTargetDate,
            iconKey: iconKey,
            colorValue: colorValue,
            note: note,
          );

  Future<void> archive(int id, bool archived) =>
      _ref.read(savingsGoalRepositoryProvider).setArchived(id, archived);

  Future<void> delete(int id) =>
      _ref.read(savingsGoalRepositoryProvider).delete(id);
}

final goalActionsProvider = Provider<GoalActions>((ref) => GoalActions(ref));
