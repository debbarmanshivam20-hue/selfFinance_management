import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/money.dart';
import '../../models/analytics.dart';
import '../../models/enums.dart';
import '../../models/transaction_filter.dart';
import '../../models/transaction_view.dart';
import '../../providers/core_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/states.dart';
import '../../widgets/transaction_tile.dart';
import 'transaction_detail_sheet.dart';

/// Full transaction history: search, filter, sort, and per-day grouping.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late final TextEditingController _searchController =
      TextEditingController(text: ref.read(transactionFilterProvider).query);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = ref.watch(moneyFormatterProvider);
    final filter = ref.watch(transactionFilterProvider);
    final controller = ref.read(transactionFilterProvider.notifier);
    final transactions = ref.watch(filteredTransactionsProvider);
    final totals = ref.watch(filteredTotalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            onPressed: () => _showSortSheet(context, controller, filter.sort),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
              child: TextField(
                controller: _searchController,
                onChanged: controller.setQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search transactions',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: filter.query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            controller.setQuery('');
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            _TypeFilterRow(filter: filter, controller: controller),
            const SizedBox(height: Gap.sm),
            _DateFilterRow(filter: filter, controller: controller),
            if (filter.isNarrowed) ...[
              const SizedBox(height: Gap.xs),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: Gap.lg),
                  child: TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      controller.clearFilters();
                    },
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: const Text('Clear filters'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: Gap.sm),
            Expanded(
              child: AsyncView<List<TransactionView>>(
                value: transactions,
                loading: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: LoadingList(),
                ),
                builder: (context, items) {
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: filter.isNarrowed
                          ? 'No matching transactions'
                          : 'No transactions yet',
                      message: filter.isNarrowed
                          ? 'Try a different search or clear your filters.'
                          : 'Start tracking your finances by adding your '
                              'first transaction.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.lg, 0, Gap.lg, Gap.navClearance),
                    children: [
                      if (totals != null && filter.preset != DatePreset.all)
                        _SummaryStrip(totals: totals, formatter: formatter),
                      ..._groupedChildren(context, items, formatter),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupedChildren(
    BuildContext context,
    List<TransactionView> items,
    MoneyFormatter formatter,
  ) {
    final widgets = <Widget>[];
    DateTime? lastDay;
    var dayTotal = Money.zero;
    final pendingTiles = <Widget>[];

    void flush() {
      if (lastDay == null) return;
      widgets.add(TransactionDateHeader(
        date: lastDay,
        total: dayTotal,
        formatter: formatter,
      ));
      widgets.addAll(pendingTiles);
      pendingTiles.clear();
    }

    for (final item in items) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      if (lastDay == null || day != lastDay) {
        flush();
        lastDay = day;
        dayTotal = Money.zero;
      }
      if (item.type == TransactionType.income) {
        dayTotal += item.amount;
      } else if (item.type == TransactionType.expense ||
          item.type == TransactionType.savings) {
        dayTotal -= item.amount;
      }
      pendingTiles.add(
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: TransactionTile(
            transaction: item,
            formatter: formatter,
            showDate: false,
            onTap: () => showTransactionDetail(context, item.id),
          ),
        ),
      );
    }
    flush();
    return widgets;
  }

  void _showSortSheet(
    BuildContext context,
    TransactionFilterController controller,
    TransactionSort current,
  ) {
    showAppSheet<void>(
      context: context,
      builder: (context) => AppSheet(
        title: 'Sort by',
        child: RadioGroup<TransactionSort>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) controller.setSort(value);
            Navigator.of(context).pop();
          },
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            children: [
              for (final sort in TransactionSort.values)
                RadioListTile<TransactionSort>(
                  value: sort,
                  title: Text(sort.label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeFilterRow extends StatelessWidget {
  const _TypeFilterRow({required this.filter, required this.controller});

  final TransactionFilter filter;
  final TransactionFilterController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;

    Color colorFor(TransactionType type) => switch (type) {
          TransactionType.income => palette.income,
          TransactionType.expense => palette.expense,
          TransactionType.savings => palette.savings,
          TransactionType.transfer => palette.transfer,
        };

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        children: [
          _FilterChip(
            label: 'All',
            selected: !filter.hasTypeFilter,
            onSelected: () => controller.setTypes(const {}),
          ),
          const SizedBox(width: Gap.sm),
          for (final type in TransactionType.values) ...[
            _FilterChip(
              label: type.label,
              selected: filter.types.contains(type),
              color: colorFor(type),
              onSelected: () => controller.toggleType(type),
            ),
            const SizedBox(width: Gap.sm),
          ],
        ],
      ),
    );
  }
}

class _DateFilterRow extends StatelessWidget {
  const _DateFilterRow({required this.filter, required this.controller});

  final TransactionFilter filter;
  final TransactionFilterController controller;

  static const _presets = <DatePreset>[
    DatePreset.all,
    DatePreset.today,
    DatePreset.thisWeek,
    DatePreset.thisMonth,
    DatePreset.lastMonth,
    DatePreset.thisYear,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        children: [
          for (final preset in _presets) ...[
            _FilterChip(
              label: preset.label,
              selected: filter.preset == preset,
              small: true,
              onSelected: () => controller.setPreset(preset),
            ),
            const SizedBox(width: Gap.sm),
          ],
          _FilterChip(
            label: filter.preset == DatePreset.custom
                ? _rangeLabel(filter.customRange)
                : 'Custom range',
            selected: filter.preset == DatePreset.custom,
            small: true,
            icon: Icons.date_range_rounded,
            onSelected: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 10),
                lastDate: DateTime(now.year + 1),
                initialDateRange: filter.customRange == null
                    ? null
                    : DateTimeRange(
                        start: filter.customRange!.start,
                        end: filter.customRange!.end
                            .subtract(const Duration(days: 1)),
                      ),
              );
              if (picked != null) {
                controller.setCustomRange(DateRange(
                  start: DateTime(
                      picked.start.year, picked.start.month, picked.start.day),
                  end: DateTime(
                      picked.end.year, picked.end.month, picked.end.day + 1),
                  label: 'Custom range',
                ));
              }
            },
          ),
        ],
      ),
    );
  }

  String _rangeLabel(DateRange? range) {
    if (range == null) return 'Custom range';
    final end = range.end.subtract(const Duration(days: 1));
    return '${DateLabels.short.format(range.start)} - '
        '${DateLabels.short.format(end)}';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
    this.small = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;
  final bool small;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    final accent = color ?? palette.savings;

    return ChoiceChip(
      label: Text(label),
      avatar: icon == null ? null : Icon(icon, size: 14),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: small ? 12 : null,
            color: selected ? accent : palette.textSecondary,
          ),
      selectedColor: accent.withValues(alpha: 0.16),
      backgroundColor: palette.cardElevated,
      side: BorderSide(color: selected ? accent : palette.hairline),
      shape: const StadiumBorder(),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.totals, required this.formatter});

  final PeriodTotals totals;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        child: Row(
          children: [
            Expanded(
              child: _StripMetric(
                label: 'Income',
                money: totals.income,
                type: TransactionType.income,
                formatter: formatter,
              ),
            ),
            Container(width: 1, height: 30, color: palette.hairline),
            Expanded(
              child: _StripMetric(
                label: 'Expense',
                money: totals.expense,
                type: TransactionType.expense,
                formatter: formatter,
              ),
            ),
            Container(width: 1, height: 30, color: palette.hairline),
            Expanded(
              child: _StripMetric(
                label: 'Savings',
                money: totals.savings,
                type: TransactionType.savings,
                formatter: formatter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StripMetric extends StatelessWidget {
  const _StripMetric({
    required this.label,
    required this.money,
    required this.type,
    required this.formatter,
  });

  final String label;
  final Money money;
  final TransactionType type;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: palette.textTertiary),
        ),
        const SizedBox(height: 3),
        FittedBox(
          child: AmountText(
            money: money,
            formatter: formatter,
            type: type,
            size: 15,
            showSign: false,
            showDecimals: false,
          ),
        ),
      ],
    );
  }
}
