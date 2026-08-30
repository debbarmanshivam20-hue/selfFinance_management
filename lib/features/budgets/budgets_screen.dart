import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_icons.dart';
import '../../core/database/app_database.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/money.dart';
import '../../models/analytics.dart';
import '../../models/enums.dart';
import '../../providers/budget_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/pickers.dart';
import '../../widgets/progress.dart';
import '../../widgets/states.dart';

/// Monthly budgets: what has been set aside per category and how much of it
/// has actually been spent.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(budgetPeriodProvider);
    final calendar = ref.watch(calendarProvider);
    final range = ref.watch(budgetPeriodRangeProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final statuses = ref.watch(selectedBudgetStatusesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
            child: Row(
              children: [
                IconButton(
                  onPressed: () =>
                      ref.read(budgetPeriodProvider.notifier).shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    calendar.monthLabel(range.start),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(budgetPeriodProvider.notifier).shift(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<BudgetStatus>>(
              value: statuses,
              builder: (context, items) {
                if (items.isEmpty) {
                  return _EmptyBudgets(period: period);
                }
                final overall =
                    items.where((s) => s.category == null).toList();
                final perCategory =
                    items.where((s) => s.category != null).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.lg, Gap.sm, Gap.lg, Gap.huge),
                  children: [
                    for (final status in [...overall, ...perCategory])
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.sm),
                        child: BudgetCard(
                          status: status,
                          formatter: formatter,
                          onTap: () => _openEditor(
                            context,
                            period: period,
                            existing: status,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, period: period),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New budget'),
      ),
    );
  }

  static Future<void> _openEditor(
    BuildContext context, {
    required BudgetPeriod period,
    BudgetStatus? existing,
  }) {
    return showAppSheet<void>(
      context: context,
      builder: (context) => _BudgetEditorSheet(period: period, existing: existing),
    );
  }
}

class _EmptyBudgets extends ConsumerWidget {
  const _EmptyBudgets({required this.period});

  final BudgetPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyState(
      icon: Icons.pie_chart_outline_rounded,
      title: 'No budgets for this month',
      message:
          'Set a limit for a category, or the month overall, to track how '
          'much of it you have used.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () =>
                BudgetsScreen._openEditor(context, period: period),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create a budget'),
          ),
          const SizedBox(height: Gap.sm),
          TextButton.icon(
            onPressed: () async {
              final copied =
                  await ref.read(budgetActionsProvider).copyFromPreviousMonth(period);
              if (!context.mounted) return;
              AppSnack.info(
                context,
                copied == 0
                    ? 'No budgets from last month to copy.'
                    : 'Copied $copied budget${copied == 1 ? '' : 's'} from last month.',
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy from last month'),
          ),
        ],
      ),
    );
  }
}

class _BudgetEditorSheet extends ConsumerStatefulWidget {
  const _BudgetEditorSheet({required this.period, this.existing});

  final BudgetPeriod period;
  final BudgetStatus? existing;

  @override
  ConsumerState<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends ConsumerState<_BudgetEditorSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.existing == null
        ? ''
        : ref.read(moneyFormatterProvider).plain(widget.existing!.limit),
  );
  int? _categoryId;
  bool _overall = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.category?.id;
    _overall = _isEditing && widget.existing!.category == null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || amount.minor <= 0) {
      AppSnack.error(context, 'Enter a budget greater than zero.');
      return;
    }
    if (!_overall && _categoryId == null) {
      AppSnack.error(context, 'Choose a category, or budget the whole month.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(budgetActionsProvider).upsert(
            categoryId: _overall ? null : _categoryId,
            year: widget.period.year,
            month: widget.period.month,
            amount: amount,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(context, _isEditing ? 'Budget updated' : 'Budget created');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(context, describeFailure(error));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this budget?',
      message: 'You can set it again at any time.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(budgetActionsProvider)
          .delete(widget.existing!.budget.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(context, 'Budget deleted');
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, describeFailure(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    final settings = ref.watch(settingsProvider);
    final categories =
        ref.watch(categoriesByKindProvider(CategoryKind.expense)).valueOrNull ??
            const <CategoryRow>[];
    final selectedCategory =
        categories.where((c) => c.id == _categoryId).firstOrNull;

    return AppSheet(
      title: _isEditing ? 'Edit budget' : 'New budget',
      subtitle: 'For ${ref.read(calendarProvider).monthLabel(
        ref.read(calendarProvider).monthOf(widget.period.year, widget.period.month).start,
      )}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isEditing) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Budget the whole month'),
                subtitle: const Text('Instead of a single category'),
                value: _overall,
                onChanged: (value) => setState(() => _overall = value),
              ),
              const SizedBox(height: Gap.md),
            ],
            if (!_overall) ...[
              SelectorField(
                label: 'Category',
                required: true,
                placeholder: 'Choose a category',
                value: selectedCategory?.name,
                icon: selectedCategory == null
                    ? Icons.category_outlined
                    : AppIcons.resolve(selectedCategory.iconKey),
                iconColor: selectedCategory == null
                    ? null
                    : Color(selectedCategory.colorValue),
                onTap: _isEditing
                    ? () {}
                    : () async {
                        final picked = await showCategoryPicker(
                          context: context,
                          categories: categories,
                          selectedId: _categoryId,
                        );
                        if (picked != null) {
                          setState(() => _categoryId = picked.id);
                        }
                      },
              ),
              const SizedBox(height: Gap.xl),
            ],
            FieldLabel('Budget amount', required: true),
            AmountField(
              controller: _amountController,
              symbol: settings.currency.symbol,
              accent: palette.savings,
            ),
            const SizedBox(height: Gap.xxl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEditing ? 'Save changes' : 'Create budget'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: Gap.sm),
              OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.expense,
                  side: BorderSide(color: palette.expense.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
