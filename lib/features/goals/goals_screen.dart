import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_icons.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/money.dart';
import '../../models/analytics.dart';
import '../../models/enums.dart';
import '../../providers/core_providers.dart';
import '../../providers/goal_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/pickers.dart';
import '../../widgets/progress.dart';
import '../../widgets/states.dart';
import '../shell/add_button.dart';

/// Savings goals: what the user is putting money aside for, and how close
/// each one is to its target.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(moneyFormatterProvider);
    final goals = ref.watch(goalProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      body: AsyncView<List<GoalProgress>>(
        value: goals,
        builder: (context, items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.flag_outlined,
              title: 'No savings goals yet',
              message: 'Create a goal to earmark savings towards something '
                  'specific, like a laptop or an emergency fund.',
              action: FilledButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create a goal'),
              ),
            );
          }
          return ListView.separated(
            padding:
                const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
            itemBuilder: (context, index) {
              final progress = items[index];
              return GoalCard(
                progress: progress,
                formatter: formatter,
                onTap: () => _openEditor(context, existing: progress),
                onAddMoney: () => openAddTransaction(
                  context,
                  type: TransactionType.savings,
                  goalId: progress.goal.id,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New goal'),
      ),
    );
  }

  static Future<void> _openEditor(
    BuildContext context, {
    GoalProgress? existing,
  }) {
    return showAppSheet<void>(
      context: context,
      builder: (context) => _GoalEditorSheet(existing: existing),
    );
  }
}

class _GoalEditorSheet extends ConsumerStatefulWidget {
  const _GoalEditorSheet({this.existing});

  final GoalProgress? existing;

  @override
  ConsumerState<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<_GoalEditorSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _targetController = TextEditingController(
    text: widget.existing == null
        ? ''
        : ref.read(moneyFormatterProvider).plain(widget.existing!.target),
  );
  late final TextEditingController _openingController = TextEditingController(
    text: widget.existing == null
        ? ''
        : ref
            .read(moneyFormatterProvider)
            .plain(Money(widget.existing!.goal.openingMinor)),
  );
  final TextEditingController _noteController = TextEditingController();

  late String _iconKey = widget.existing?.goal.iconKey ?? 'goal';
  late int _colorValue = widget.existing?.goal.colorValue ?? AppPalette.at(2);
  DateTime? _targetDate;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _targetDate = widget.existing?.goal.targetDate;
    _noteController.text = widget.existing?.goal.note ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _openingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnack.error(context, 'Give the goal a name.');
      return;
    }
    final target = Money.tryParse(_targetController.text);
    if (target == null || target.minor <= 0) {
      AppSnack.error(context, 'Set a target greater than zero.');
      return;
    }
    final opening = Money.tryParse(_openingController.text) ?? Money.zero;

    setState(() => _saving = true);
    try {
      final actions = ref.read(goalActionsProvider);
      if (_isEditing) {
        await actions.update(
          widget.existing!.goal.id,
          name: name,
          target: target,
          opening: opening,
          targetDate: _targetDate,
          clearTargetDate: _targetDate == null,
          iconKey: _iconKey,
          colorValue: _colorValue,
          note: _noteController.text,
        );
      } else {
        await actions.create(
          name: name,
          target: target,
          opening: opening,
          targetDate: _targetDate,
          iconKey: _iconKey,
          colorValue: _colorValue,
          note: _noteController.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(context, _isEditing ? 'Goal updated' : 'Goal created');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(context, describeFailure(error));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "${widget.existing!.name}"?',
      message: 'Savings already recorded towards this goal stay in your '
          'history - they just will not be earmarked any more.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(goalActionsProvider).delete(widget.existing!.goal.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(context, 'Goal deleted');
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, describeFailure(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    final settings = ref.watch(settingsProvider);
    final accent = Color(_colorValue);

    return AppSheet(
      title: _isEditing ? 'Edit goal' : 'New savings goal',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(Corners.pill),
                onTap: () async {
                  final picked = await showIconPicker(
                    context: context,
                    selectedKey: _iconKey,
                    accent: accent,
                  );
                  if (picked != null) setState(() => _iconKey = picked);
                },
                child: IconBadge(
                  icon: AppIcons.resolve(_iconKey),
                  color: accent,
                  size: 64,
                  iconSize: 28,
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Center(
              child: Text(
                'Tap to change icon',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: palette.textTertiary),
              ),
            ),
            const SizedBox(height: Gap.xl),
            AppTextField(
              controller: _nameController,
              label: 'Goal name',
              hint: 'e.g. New laptop',
              required: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: Gap.lg),
            AppTextField(
              controller: _targetController,
              label: 'Target amount',
              hint: '${settings.currency.symbol} 0.00',
              icon: Icons.flag_outlined,
              required: true,
            ),
            const SizedBox(height: Gap.lg),
            AppTextField(
              controller: _openingController,
              label: 'Already saved (optional)',
              hint: '${settings.currency.symbol} 0.00',
              icon: Icons.savings_outlined,
            ),
            const SizedBox(height: Gap.lg),
            DateSelectorField(
              label: 'Target date (optional)',
              value: _targetDate,
              allowClear: true,
              firstDate: DateTime.now(),
              onChanged: (value) => setState(() => _targetDate = value),
            ),
            const SizedBox(height: Gap.lg),
            AppTextField(
              controller: _noteController,
              label: 'Note (optional)',
              hint: 'Anything worth remembering',
              maxLines: 2,
            ),
            const SizedBox(height: Gap.xl),
            FieldLabel('Colour'),
            ColorSwatchPicker(
              selectedValue: _colorValue,
              onSelected: (value) => setState(() => _colorValue = value),
            ),
            const SizedBox(height: Gap.xxl),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: accent),
              child: Text(_isEditing ? 'Save changes' : 'Create goal'),
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
