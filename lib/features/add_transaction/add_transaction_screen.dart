import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_icons.dart';
import '../../core/database/app_database.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/money.dart';
import '../../models/enums.dart';
import '../../models/transaction_draft.dart';
import '../../providers/core_providers.dart';
import '../../providers/goal_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/pickers.dart';
import '../settings/manage_categories_screen.dart';

/// Create or edit a single transaction.
///
/// The form validates locally for immediate feedback, and the draft validates
/// again in the domain layer before anything reaches the database.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.initialType,
    this.transactionId,
    this.initialGoalId,
  });

  final TransactionType? initialType;
  final int? transactionId;
  final int? initialGoalId;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  late TransactionType _type;
  DateTime _date = DateTime.now();
  int? _categoryId;
  int? _paymentMethodId;
  int? _toPaymentMethodId;
  int? _goalId;

  bool _loading = false;
  bool _saving = false;
  bool _defaultsApplied = false;
  String? _categoryError;
  String? _accountError;

  bool get _isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ??
        (widget.initialGoalId != null
            ? TransactionType.savings
            : TransactionType.expense);
    _goalId = widget.initialGoalId;
    if (_isEditing) _loadExisting();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final row =
          await ref.read(transactionRepositoryProvider).findRow(widget.transactionId!);
      if (!mounted) return;
      if (row == null) {
        Navigator.of(context).pop();
        return;
      }
      final formatter = ref.read(moneyFormatterProvider);
      setState(() {
        _type = row.type;
        _amountController.text = formatter.plain(Money(row.amountMinor));
        _titleController.text = row.title;
        _notesController.text = row.notes ?? '';
        _date = row.date;
        _categoryId = row.categoryId;
        _paymentMethodId = row.paymentMethodId;
        _toPaymentMethodId = row.toPaymentMethodId;
        _goalId = row.goalId;
        _defaultsApplied = true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnack.error(context, describeFailure(error));
      Navigator.of(context).pop();
    }
  }

  /// Pre-selects a sensible account on a brand new entry so the user only has
  /// to type an amount in the common case.
  void _applyDefaults(List<PaymentMethodRow> methods) {
    if (_defaultsApplied || methods.isEmpty) return;
    _defaultsApplied = true;
    _paymentMethodId ??= methods.first.id;
    if (_type == TransactionType.transfer && methods.length > 1) {
      _toPaymentMethodId ??= methods[1].id;
    }
  }

  Color get _accent {
    final palette = context.finance;
    return switch (_type) {
      TransactionType.income => palette.income,
      TransactionType.expense => palette.expense,
      TransactionType.savings => palette.savings,
      TransactionType.transfer => palette.transfer,
    };
  }

  void _changeType(TransactionType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      // A category belongs to one kind, so it cannot survive a type change.
      _categoryId = null;
      _categoryError = null;
      _accountError = null;
      if (type != TransactionType.savings) _goalId = null;
      if (type != TransactionType.transfer) _toPaymentMethodId = null;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _categoryError = (_type.requiresCategory && _categoryId == null)
          ? 'Choose a category'
          : null;
      _accountError = (_type.requiresDestination &&
              (_paymentMethodId == null || _toPaymentMethodId == null))
          ? 'Choose both accounts'
          : null;
    });
    if (!formValid || _categoryError != null || _accountError != null) return;

    final amount = Money.tryParse(_amountController.text);
    if (amount == null) return;

    // An empty title falls back to the category or type name rather than
    // blocking the user on a field that is really optional in practice.
    final categories = ref.read(categoriesByIdProvider);
    final fallbackTitle = _type == TransactionType.transfer
        ? 'Transfer'
        : (categories[_categoryId]?.name ?? _type.label);
    final title = _titleController.text.trim().isEmpty
        ? fallbackTitle
        : _titleController.text.trim();

    final draft = TransactionDraft(
      id: widget.transactionId,
      type: _type,
      amount: amount,
      date: _date,
      title: title,
      categoryId: _categoryId,
      paymentMethodId: _paymentMethodId,
      toPaymentMethodId: _toPaymentMethodId,
      goalId: _goalId,
      notes: _notesController.text,
      currencyCode: ref.read(settingsProvider).currencyCode,
    );

    setState(() => _saving = true);
    try {
      final actions = ref.read(transactionActionsProvider);
      if (_isEditing) {
        await actions.update(draft);
      } else {
        await actions.add(draft);
      }
      if (!mounted) return;
      // Every stream watching the transactions table has already been
      // notified by drift at this point, so the dashboard, charts and
      // analytics behind this screen are up to date before it closes.
      Navigator.of(context).pop(true);
      AppSnack.success(
        context,
        _isEditing ? 'Transaction updated' : 'Transaction saved',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(context, describeFailure(error));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this transaction?',
      message: 'This entry will be removed from your history and all totals.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(transactionActionsProvider).delete(widget.transactionId!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppSnack.success(context, 'Transaction deleted');
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, describeFailure(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;
    final settings = ref.watch(settingsProvider);
    final formatter = ref.watch(moneyFormatterProvider);

    final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? const [];
    _applyDefaults(methods);

    final kind = CategoryKind.forTransactionType(_type);
    final categories = kind == null
        ? const <CategoryRow>[]
        : (ref.watch(categoriesByKindProvider(kind)).valueOrNull ?? const []);

    final selectedCategory =
        categories.where((c) => c.id == _categoryId).firstOrNull;
    final selectedMethod =
        methods.where((m) => m.id == _paymentMethodId).firstOrNull;
    final selectedDestination =
        methods.where((m) => m.id == _toPaymentMethodId).firstOrNull;
    final goals = ref.watch(goalProgressProvider).valueOrNull ?? const [];
    final selectedGoal = goals.where((g) => g.goal.id == _goalId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit transaction' : 'New transaction'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _saving ? null : _delete,
              tooltip: 'Delete transaction',
              color: palette.expense,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.lg, Gap.sm, Gap.lg, Gap.huge),
                  children: [
                    _TypeSelector(
                      selected: _type,
                      onChanged: _saving ? null : _changeType,
                    ),
                    const SizedBox(height: Gap.xxl),

                    // Amount ------------------------------------------------
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.07),
                        borderRadius: Corners.card,
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_type.label} amount',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: palette.textTertiary),
                          ),
                          AmountField(
                            controller: _amountController,
                            symbol: settings.currency.symbol,
                            accent: _accent,
                            autofocus: !_isEditing,
                            onChanged: (_) => setState(() {}),
                          ),
                          _QuickAmounts(
                            onAdd: (value) {
                              final current =
                                  Money.tryParse(_amountController.text) ??
                                      Money.zero;
                              final next = current + Money.fromMajor(value);
                              _amountController.text = formatter.plain(next);
                              setState(() {});
                            },
                            onClear: () {
                              _amountController.clear();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.xl),

                    // Category ---------------------------------------------
                    if (_type.requiresCategory) ...[
                      SelectorField(
                        label: 'Category',
                        required: true,
                        placeholder: 'Choose a category',
                        errorText: _categoryError,
                        value: selectedCategory?.name,
                        icon: selectedCategory == null
                            ? Icons.category_outlined
                            : AppIcons.resolve(selectedCategory.iconKey),
                        iconColor: selectedCategory == null
                            ? null
                            : Color(selectedCategory.colorValue),
                        onTap: () async {
                          final picked = await showCategoryPicker(
                            context: context,
                            categories: categories,
                            selectedId: _categoryId,
                            onCreateNew: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ManageCategoriesScreen(),
                              ),
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _categoryId = picked.id;
                              _categoryError = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: Gap.lg),
                    ],

                    // Accounts ---------------------------------------------
                    SelectorField(
                      label: _type == TransactionType.transfer
                          ? 'From account'
                          : 'Payment method',
                      placeholder: 'Choose an account',
                      value: selectedMethod?.name,
                      errorText: _accountError,
                      icon: selectedMethod == null
                          ? Icons.account_balance_wallet_outlined
                          : AppIcons.resolve(selectedMethod.iconKey),
                      iconColor: selectedMethod == null
                          ? null
                          : Color(selectedMethod.colorValue),
                      onTap: () async {
                        final picked = await showPaymentMethodPicker(
                          context: context,
                          methods: methods,
                          selectedId: _paymentMethodId,
                          excludeId: _type == TransactionType.transfer
                              ? _toPaymentMethodId
                              : null,
                        );
                        if (picked != null) {
                          setState(() {
                            _paymentMethodId = picked.id;
                            _accountError = null;
                          });
                        }
                      },
                    ),

                    if (_type == TransactionType.transfer) ...[
                      const SizedBox(height: Gap.lg),
                      SelectorField(
                        label: 'To account',
                        required: true,
                        placeholder: 'Choose destination',
                        value: selectedDestination?.name,
                        errorText: _accountError,
                        icon: selectedDestination == null
                            ? Icons.swap_horiz_rounded
                            : AppIcons.resolve(selectedDestination.iconKey),
                        iconColor: selectedDestination == null
                            ? null
                            : Color(selectedDestination.colorValue),
                        onTap: () async {
                          final picked = await showPaymentMethodPicker(
                            context: context,
                            methods: methods,
                            selectedId: _toPaymentMethodId,
                            excludeId: _paymentMethodId,
                            title: 'Transfer to',
                          );
                          if (picked != null) {
                            setState(() {
                              _toPaymentMethodId = picked.id;
                              _accountError = null;
                            });
                          }
                        },
                      ),
                    ],

                    // Goal --------------------------------------------------
                    if (_type == TransactionType.savings) ...[
                      const SizedBox(height: Gap.lg),
                      SelectorField(
                        label: 'Savings goal (optional)',
                        placeholder: 'Not linked to a goal',
                        value: selectedGoal?.name,
                        icon: selectedGoal == null
                            ? Icons.flag_outlined
                            : AppIcons.resolve(selectedGoal.goal.iconKey),
                        iconColor: selectedGoal == null
                            ? null
                            : Color(selectedGoal.goal.colorValue),
                        trailing: _goalId == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                tooltip: 'Unlink goal',
                                onPressed: () => setState(() => _goalId = null),
                              ),
                        onTap: () async {
                          final picked = await showGoalPicker(
                            context: context,
                            goals: goals,
                            formatter: formatter,
                            selectedId: _goalId,
                          );
                          if (picked != null) {
                            setState(() => _goalId = picked.id);
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: Gap.lg),

                    // Date --------------------------------------------------
                    DateSelectorField(
                      value: _date,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onChanged: (value) {
                        if (value != null) setState(() => _date = value);
                      },
                    ),
                    const SizedBox(height: Gap.sm),
                    _QuickDates(
                      selected: _date,
                      onSelected: (value) => setState(() => _date = value),
                    ),

                    const SizedBox(height: Gap.lg),
                    AppTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: selectedCategory?.name ?? 'What was this for?',
                      icon: Icons.title_rounded,
                      maxLength: 120,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: Gap.lg),
                    AppTextField(
                      controller: _notesController,
                      label: 'Notes (optional)',
                      hint: 'Anything worth remembering',
                      maxLines: 3,
                      maxLength: 2000,
                    ),

                    const SizedBox(height: Gap.xxl),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _accent.withValues(alpha: 0.4),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : (_isEditing ? 'Save changes' : 'Save transaction'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Segmented control for the four transaction types.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final TransactionType selected;
  final ValueChanged<TransactionType>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    final theme = Theme.of(context);

    Color colorFor(TransactionType type) => switch (type) {
          TransactionType.income => palette.income,
          TransactionType.expense => palette.expense,
          TransactionType.savings => palette.savings,
          TransactionType.transfer => palette.transfer,
        };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.cardElevated,
        borderRadius: Corners.tile,
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: TransactionType.values.map((type) {
          final isSelected = type == selected;
          final color = colorFor(type);
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: type.label,
              excludeSemantics: true,
              child: InkWell(
                onTap: onChanged == null ? null : () => onChanged!(type),
                borderRadius: BorderRadius.circular(Corners.sm),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  curve: Motion.standard,
                  padding: const EdgeInsets.symmetric(vertical: Gap.md),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(Corners.sm),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        type.icon,
                        size: 19,
                        color: isSelected ? color : palette.textTertiary,
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        type.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected ? color : palette.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickAmounts extends StatelessWidget {
  const _QuickAmounts({required this.onAdd, required this.onClear});

  final ValueChanged<int> onAdd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: Gap.sm,
        children: [
          for (final value in const [100, 500, 1000, 5000])
            ActionChip(
              label: Text('+$value'),
              onPressed: () => onAdd(value),
              visualDensity: VisualDensity.compact,
            ),
          ActionChip(
            avatar: Icon(Icons.backspace_outlined,
                size: 14, color: palette.textTertiary),
            label: const Text('Clear'),
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _QuickDates extends StatelessWidget {
  const _QuickDates({required this.selected, required this.onSelected});

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final options = <String, DateTime>{
      'Today': DateTime(now.year, now.month, now.day),
      'Yesterday': DateTime(now.year, now.month, now.day - 1),
      DateLabels.weekdayShort.format(DateTime(now.year, now.month, now.day - 2)):
          DateTime(now.year, now.month, now.day - 2),
    };

    return Wrap(
      spacing: Gap.sm,
      children: options.entries.map((entry) {
        final isSelected = selected.year == entry.value.year &&
            selected.month == entry.value.month &&
            selected.day == entry.value.day;
        return ChoiceChip(
          label: Text(entry.key),
          selected: isSelected,
          onSelected: (_) => onSelected(entry.value),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}
