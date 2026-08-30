import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/money.dart';
import '../../models/analytics.dart';
import '../../models/enums.dart';
import '../../providers/analytics_providers.dart';
import '../../providers/budget_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/goal_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charts/category_donut_chart.dart';
import '../../widgets/charts/chart_card.dart';
import '../../widgets/charts/daily_expense_chart.dart';
import '../../widgets/progress.dart';
import '../../widgets/states.dart';
import '../../widgets/transaction_tile.dart';
import '../budgets/budgets_screen.dart';
import '../goals/goals_screen.dart';
import '../shell/add_button.dart';
import '../shell/shell_providers.dart';
import '../transactions/transaction_detail_sheet.dart';
import 'widgets/balance_hero_card.dart';
import 'widgets/insights_panel.dart';
import 'widgets/period_summary_card.dart';

/// The home screen: current position, this month's shape, and what needs
/// attention - all read from the local database.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.finance;
    final formatter = ref.watch(moneyFormatterProvider);
    final calendar = ref.watch(calendarProvider);
    final now = ref.watch(nowProvider);

    final allTime = ref.watch(allTimeTotalsProvider);
    final today = ref.watch(todayTotalsProvider);
    final week = ref.watch(weekTotalsProvider);
    final month = ref.watch(monthTotalsProvider);
    final monthRange = ref.watch(thisMonthRangeProvider);
    final expenseTrend = ref.watch(expenseTrendProvider);
    final recent = ref.watch(recentTransactionsProvider);
    final totalCount = ref.watch(transactionCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            // Streams are already live; this simply re-reads "today" so a
            // pull-to-refresh across midnight does the expected thing.
            ref.invalidate(nowProvider);
            await Future<void>.delayed(Motion.fast);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                Gap.lg, Gap.sm, Gap.lg, Gap.navClearance),
            children: [
              _Greeting(now: now),
              const SizedBox(height: Gap.lg),

              // Hero ---------------------------------------------------------
              AsyncView<PeriodTotals>(
                value: allTime,
                loading: const LoadingCard(height: 150),
                builder: (context, totals) => BalanceHeroCard(
                  totals: totals,
                  formatter: formatter,
                  onInfo: () => _showBalanceExplainer(context),
                ),
              ).animate().fadeIn(duration: Motion.normal).slideY(
                    begin: 0.06,
                    end: 0,
                    duration: Motion.normal,
                    curve: Motion.emphasized,
                  ),

              const SizedBox(height: Gap.md),

              // Today / week -------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: QuickStatTile(
                      label: "Today's spend",
                      money: today.valueOrNull?.expense ?? Money.zero,
                      formatter: formatter,
                      icon: Icons.today_rounded,
                      color: palette.expense,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: QuickStatTile(
                      label: "Today's income",
                      money: today.valueOrNull?.income ?? Money.zero,
                      formatter: formatter,
                      icon: Icons.savings_outlined,
                      color: palette.income,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: QuickStatTile(
                      label: 'This week',
                      money: week.valueOrNull?.expense ?? Money.zero,
                      formatter: formatter,
                      icon: Icons.date_range_rounded,
                      color: palette.transfer,
                    ),
                  ),
                ],
              ).animate(delay: 60.ms).fadeIn(duration: Motion.normal),

              const SizedBox(height: Gap.xl),

              // This month ---------------------------------------------------
              AsyncView<PeriodTotals>(
                value: month,
                loading: const LoadingCard(height: 140),
                builder: (context, totals) => PeriodSummaryCard(
                  title: calendar.monthLabel(monthRange.start),
                  totals: totals,
                  formatter: formatter,
                  expenseChange: expenseTrend.valueOrNull,
                ),
              ).animate(delay: 100.ms).fadeIn(duration: Motion.normal),

              const SizedBox(height: Gap.xl),

              // Daily spending ------------------------------------------------
              _DailySpendSection(range: monthRange),

              const SizedBox(height: Gap.xl),

              // Category split ------------------------------------------------
              _CategorySection(range: monthRange),

              const SizedBox(height: Gap.xl),

              // Budgets --------------------------------------------------------
              _BudgetSection(),

              const SizedBox(height: Gap.xl),

              // Goals ----------------------------------------------------------
              _GoalSection(),

              const SizedBox(height: Gap.xl),

              // Insights --------------------------------------------------------
              SectionHeader(
                title: 'Insights',
                subtitle: 'Generated from your own records',
              ),
              AsyncView<List<Insight>>(
                value: ref.watch(insightsProvider),
                loading: const LoadingCard(height: 90, lines: 2),
                builder: (context, insights) =>
                    InsightsPanel(insights: insights, limit: 4),
              ),

              const SizedBox(height: Gap.xl),

              // Recent activity ---------------------------------------------
              SectionHeader(
                title: 'Recent activity',
                action: totalCount == 0
                    ? null
                    : TextButton(
                        onPressed: () => ref
                            .read(shellTabProvider.notifier)
                            .select(ShellTabController.history),
                        child: const Text('View all'),
                      ),
              ),
              AsyncView<List<dynamic>>(
                value: recent,
                loading: const LoadingList(count: 3),
                builder: (context, _) {
                  final items = recent.requireValue;
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions yet',
                      message:
                          'Start tracking your finances by adding your first '
                          'transaction.',
                      action: FilledButton.icon(
                        onPressed: () => openAddTransaction(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add a transaction'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, Touch.minTarget),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Gap.sm),
                          child: TransactionTile(
                            transaction: item,
                            formatter: formatter,
                            onTap: () =>
                                showTransactionDetail(context, item.id),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: Gap.xl),
              Center(
                child: Text(
                  '${AppInfo.name} · all data stored on this device',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: palette.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBalanceExplainer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.account_balance_wallet_rounded),
        title: const Text('How the balance is worked out'),
        content: const Text(
          'Available balance = income − expenses − savings.\n\n'
          'Money you record as savings is still yours, but it is set aside, '
          'so it is not counted as available to spend.\n\n'
          'Net worth adds savings back in: income − expenses.\n\n'
          'Transfers between your own accounts never change either figure.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    final greeting = switch (now.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                DateLabels.full.format(now),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Daily spending bar chart for the current financial month.
class _DailySpendSection extends ConsumerWidget {
  const _DailySpendSection({required this.range});

  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(moneyFormatterProvider);
    final series = ref.watch(dailySeriesProvider(range));
    final totals = ref.watch(periodTotalsProvider(range));

    return AsyncView<List<DailyPoint>>(
      value: series,
      loading: const LoadingCard(height: 200),
      builder: (context, points) {
        final hasData = points.any((point) => !point.amount.isZero);
        return ChartCard(
          title: 'Daily spending',
          subtitle: range.label,
          height: 190,
          trailing: hasData
              ? Text(
                  formatter.compact(
                      totals.valueOrNull?.expense ?? Money.zero),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.finance.expense,
                      ),
                )
              : null,
          child: hasData
              ? DailyExpenseChart(points: points, formatter: formatter)
              : const ChartEmpty(
                  message:
                      'No spending recorded this month yet. Your daily chart '
                      'will appear here.',
                ),
        );
      },
    );
  }
}

/// Category doughnut for the current financial month.
class _CategorySection extends ConsumerWidget {
  const _CategorySection({required this.range});

  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(moneyFormatterProvider);
    final categories = ref.watch(
      categoryTotalsProvider((range: range, type: TransactionType.expense)),
    );

    return AsyncView<List<CategoryTotal>>(
      value: categories,
      loading: const LoadingCard(height: 200),
      builder: (context, data) {
        if (data.isEmpty) {
          return const ChartCard(
            title: 'Where your money went',
            height: 170,
            child: ChartEmpty(
              icon: Icons.donut_large_rounded,
              message:
                  'Once you record some expenses, your category breakdown '
                  'shows up here.',
            ),
          );
        }
        final total = Money.sum(data.map((entry) => entry.total));
        return ChartCard(
          title: 'Where your money went',
          subtitle: range.label,
          height: 190,
          footer: CategoryBreakdownList(
            categories: data,
            formatter: formatter,
            limit: 4,
          ),
          child: CategoryDonutChart(
            categories: data,
            formatter: formatter,
            total: total,
          ),
        );
      },
    );
  }
}

class _BudgetSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(moneyFormatterProvider);
    final statuses = ref.watch(currentBudgetStatusesProvider);

    return Column(
      children: [
        SectionHeader(
          title: 'Budgets',
          action: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BudgetsScreen()),
            ),
            child: const Text('Manage'),
          ),
        ),
        AsyncView<List<BudgetStatus>>(
          value: statuses,
          loading: const LoadingCard(height: 80, lines: 2),
          builder: (context, data) {
            if (data.isEmpty) {
              return AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const BudgetsScreen()),
                ),
                child: Row(
                  children: [
                    IconBadge(
                      icon: Icons.pie_chart_outline_rounded,
                      color: context.finance.savings,
                      size: 38,
                      iconSize: 18,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set a monthly budget',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Track how much of each category you have used.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: context.finance.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: context.finance.textTertiary),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final status in data.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: BudgetCard(status: status, formatter: formatter),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GoalSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(moneyFormatterProvider);
    final goals = ref.watch(goalProgressProvider);

    return Column(
      children: [
        SectionHeader(
          title: 'Savings goals',
          action: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GoalsScreen()),
            ),
            child: const Text('Manage'),
          ),
        ),
        AsyncView<List<GoalProgress>>(
          value: goals,
          loading: const LoadingCard(height: 80, lines: 2),
          builder: (context, data) {
            if (data.isEmpty) {
              return AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GoalsScreen()),
                ),
                child: Row(
                  children: [
                    IconBadge(
                      icon: Icons.flag_outlined,
                      color: context.finance.income,
                      size: 38,
                      iconSize: 18,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create a savings goal',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Put money aside towards something specific.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: context.finance.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: context.finance.textTertiary),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final progress in data.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: GoalCard(
                      progress: progress,
                      formatter: formatter,
                      onAddMoney: () => openAddTransaction(
                        context,
                        type: TransactionType.savings,
                        goalId: progress.goal.id,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
