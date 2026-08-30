import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_range.dart';
import '../../models/enums.dart';
import '../../models/transaction_view.dart';
import '../../providers/core_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/dialogs.dart';
import '../shell/add_button.dart';

/// Full detail of one transaction, with edit and delete.
Future<void> showTransactionDetail(BuildContext context, int id) {
  return showAppSheet<void>(
    context: context,
    builder: (context) => _TransactionDetailSheet(id: id),
  );
}

class _TransactionDetailSheet extends ConsumerWidget {
  const _TransactionDetailSheet({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.finance;
    final formatter = ref.watch(moneyFormatterProvider);
    final transaction = ref.watch(transactionByIdProvider(id));

    return AppSheet(
      title: 'Transaction',
      child: transaction.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.huge),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Text(describeFailure(error)),
        ),
        data: (item) {
          if (item == null) {
            return const Padding(
              padding: EdgeInsets.all(Gap.xl),
              child: Text('This transaction no longer exists.'),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      IconBadge(
                        icon: item.icon,
                        color: item.accentColor(palette),
                        size: 56,
                        iconSize: 26,
                      ),
                      const SizedBox(height: Gap.md),
                      AmountText(
                        money: item.amount,
                        formatter: formatter,
                        type: item.type,
                        size: 30,
                      ),
                      const SizedBox(height: Gap.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.typeColor(palette).withValues(alpha: 0.14),
                          borderRadius: Corners.chip,
                        ),
                        child: Text(
                          item.type.label,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: item.typeColor(palette)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.xxl),
                _DetailRow(label: 'Title', value: item.title),
                if (item.type != TransactionType.transfer)
                  _DetailRow(label: 'Category', value: item.categoryName),
                _DetailRow(
                  label: item.type == TransactionType.transfer
                      ? 'Accounts'
                      : 'Payment method',
                  value: item.accountLabel,
                ),
                if (item.goal != null)
                  _DetailRow(label: 'Savings goal', value: item.goal!.name),
                _DetailRow(
                  label: 'Date',
                  value: DateLabels.full.format(item.date),
                ),
                if (item.notes != null && item.notes!.isNotEmpty)
                  _DetailRow(label: 'Notes', value: item.notes!, multiline: true),
                _DetailRow(
                  label: 'Recorded',
                  value: DateLabels.medium.format(item.row.createdAt),
                  muted: true,
                ),
                const SizedBox(height: Gap.xxl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _delete(context, ref, item),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.expense,
                          side: BorderSide(
                              color: palette.expense.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          openAddTransaction(context, transactionId: item.id);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TransactionView item,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this transaction?',
      message:
          '"${item.title}" will be removed from your history and all totals.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final actions = ref.read(transactionActionsProvider);
      final removed = await actions.delete(item.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      if (removed == null) return;
      AppSnack.action(
        context,
        'Transaction deleted',
        actionLabel: 'Undo',
        onAction: () => actions.restore(removed),
      );
    } catch (error) {
      if (!context.mounted) return;
      AppSnack.error(context, describeFailure(error));
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.multiline = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool multiline;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: (muted ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
                  ?.copyWith(color: muted ? palette.textTertiary : null),
            ),
          ),
        ],
      ),
    );
  }
}
