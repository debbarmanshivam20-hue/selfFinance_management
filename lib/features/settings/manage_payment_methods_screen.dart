import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_icons.dart';
import '../../core/database/app_database.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/money.dart';
import '../../providers/core_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/pickers.dart';
import '../../widgets/states.dart';

/// CRUD screen for the accounts / payment methods transactions move between.
class ManagePaymentMethodsScreen extends ConsumerWidget {
  const ManagePaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts & payment methods')),
      body: AsyncView<List<PaymentMethodRow>>(
        value: methods,
        builder: (context, items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No accounts yet',
              message: 'Add one with the button below.',
            );
          }
          return ListView.separated(
            padding:
                const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
            itemBuilder: (context, index) {
              final method = items[index];
              return AppCard(
                padding: const EdgeInsets.all(Gap.md),
                onTap: () => _openEditor(context, existing: method),
                child: Row(
                  children: [
                    IconBadge(
                      icon: AppIcons.resolve(method.iconKey),
                      color: Color(method.colorValue),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        method.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (method.isSystem)
                      Padding(
                        padding: const EdgeInsets.only(right: Gap.sm),
                        child: Text(
                          'Default',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: context.finance.textTertiary),
                        ),
                      ),
                    Icon(Icons.chevron_right_rounded,
                        color: context.finance.textTertiary),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New account'),
      ),
    );
  }

  static Future<void> _openEditor(
    BuildContext context, {
    PaymentMethodRow? existing,
  }) {
    return showAppSheet<void>(
      context: context,
      builder: (context) => _MethodEditorSheet(existing: existing),
    );
  }
}

class _MethodEditorSheet extends ConsumerStatefulWidget {
  const _MethodEditorSheet({this.existing});

  final PaymentMethodRow? existing;

  @override
  ConsumerState<_MethodEditorSheet> createState() => _MethodEditorSheetState();
}

class _MethodEditorSheetState extends ConsumerState<_MethodEditorSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _balanceController = TextEditingController(
    text: widget.existing == null
        ? ''
        : ref
            .read(moneyFormatterProvider)
            .plain(Money(widget.existing!.openingBalanceMinor)),
  );
  late String _iconKey = widget.existing?.iconKey ?? 'wallet';
  late int _colorValue = widget.existing?.colorValue ?? AppPalette.at(4);
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnack.error(context, 'Give the account a name.');
      return;
    }
    final opening =
        Money.tryParse(_balanceController.text, decimals: 2) ?? Money.zero;

    setState(() => _saving = true);
    try {
      final actions = ref.read(paymentMethodActionsProvider);
      if (_isEditing) {
        await actions.update(
          widget.existing!,
          name: name,
          iconKey: _iconKey,
          colorValue: _colorValue,
          openingBalance: opening,
        );
      } else {
        await actions.create(
          name: name,
          iconKey: _iconKey,
          colorValue: _colorValue,
          openingBalance: opening,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(context, _isEditing ? 'Account updated' : 'Account added');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(context, describeFailure(error));
    }
  }

  Future<void> _delete() async {
    final method = widget.existing!;
    final usage = await ref.read(paymentMethodActionsProvider).usageCount(method.id);
    if (!mounted) return;

    final message = usage == 0
        ? 'This account will be removed.'
        : method.isSystem
            ? 'This is a default account, so it will be hidden instead of '
                'deleted. $usage existing transaction${usage == 1 ? '' : 's'} '
                'will keep referencing it.'
            : '$usage transaction${usage == 1 ? '' : 's'} use this account. '
                'They will keep their amount but lose the account reference.';

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "${method.name}"?',
      message: message,
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(paymentMethodActionsProvider).delete(method);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(context, 'Account deleted');
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, describeFailure(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_colorValue);
    final symbol = ref.watch(settingsProvider).currency.symbol;

    return AppSheet(
      title: _isEditing ? 'Edit account' : 'New account',
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
                    ?.copyWith(color: context.finance.textTertiary),
              ),
            ),
            const SizedBox(height: Gap.xl),
            AppTextField(
              controller: _nameController,
              label: 'Name',
              hint: 'e.g. HDFC Bank',
              required: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: Gap.lg),
            AppTextField(
              controller: _balanceController,
              label: 'Opening balance',
              hint: '$symbol 0.00',
              icon: Icons.account_balance_wallet_outlined,
              textInputAction: TextInputAction.done,
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
              child: Text(_isEditing ? 'Save changes' : 'Add account'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: Gap.sm),
              OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.finance.expense,
                  side: BorderSide(
                      color: context.finance.expense.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
