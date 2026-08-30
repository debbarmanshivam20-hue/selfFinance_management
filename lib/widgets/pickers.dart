import 'package:flutter/material.dart';

import '../core/constants/app_icons.dart';
import '../core/database/app_database.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/money.dart';
import '../models/analytics.dart';
import 'app_card.dart';
import 'app_sheet.dart';
import 'states.dart';

/// Bottom-sheet list picker used for categories, accounts and goals.
Future<T?> showOptionPicker<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<T> options,
  required String Function(T option) labelOf,
  required IconData Function(T option) iconOf,
  required Color Function(T option) colorOf,
  String? Function(T option)? trailingOf,
  bool Function(T option)? isSelected,
  Widget? emptyState,
  Widget? footer,
}) {
  return showAppSheet<T>(
    context: context,
    builder: (context) => AppSheet(
      title: title,
      subtitle: subtitle,
      child: options.isEmpty
          ? (emptyState ??
              const EmptyState(
                icon: Icons.inbox_rounded,
                title: 'Nothing to choose from',
                message: 'Create one first, then come back here.',
                compact: true,
              ))
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xl),
              itemCount: options.length + (footer == null ? 0 : 1),
              separatorBuilder: (_, __) => const SizedBox(height: Gap.xs),
              itemBuilder: (context, index) {
                if (index == options.length) return footer!;
                final option = options[index];
                final selected = isSelected?.call(option) ?? false;
                final color = colorOf(option);
                final trailing = trailingOf?.call(option);

                return ListTile(
                  onTap: () => Navigator.of(context).pop(option),
                  leading: IconBadge(icon: iconOf(option), color: color),
                  title: Text(
                    labelOf(option),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: trailing == null ? null : Text(trailing),
                  trailing: selected
                      ? Icon(Icons.check_circle_rounded, color: color)
                      : null,
                  selected: selected,
                  selectedTileColor: color.withValues(alpha: 0.08),
                );
              },
            ),
    ),
  );
}

Future<CategoryRow?> showCategoryPicker({
  required BuildContext context,
  required List<CategoryRow> categories,
  int? selectedId,
  String title = 'Choose a category',
  VoidCallback? onCreateNew,
}) {
  return showOptionPicker<CategoryRow>(
    context: context,
    title: title,
    options: categories,
    labelOf: (category) => category.name,
    iconOf: (category) => AppIcons.resolve(category.iconKey),
    colorOf: (category) => Color(category.colorValue),
    isSelected: (category) => category.id == selectedId,
    emptyState: const EmptyState(
      icon: Icons.category_outlined,
      title: 'No categories yet',
      message: 'Add a category from Settings to file this entry under.',
      compact: true,
    ),
    footer: onCreateNew == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: Gap.md),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onCreateNew();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New category'),
            ),
          ),
  );
}

Future<PaymentMethodRow?> showPaymentMethodPicker({
  required BuildContext context,
  required List<PaymentMethodRow> methods,
  int? selectedId,
  String title = 'Choose an account',
  int? excludeId,
}) {
  final options =
      methods.where((method) => method.id != excludeId).toList(growable: false);
  return showOptionPicker<PaymentMethodRow>(
    context: context,
    title: title,
    options: options,
    labelOf: (method) => method.name,
    iconOf: (method) => AppIcons.resolve(method.iconKey),
    colorOf: (method) => Color(method.colorValue),
    isSelected: (method) => method.id == selectedId,
  );
}

Future<SavingsGoalRow?> showGoalPicker({
  required BuildContext context,
  required List<GoalProgress> goals,
  required MoneyFormatter formatter,
  int? selectedId,
}) {
  return showOptionPicker<GoalProgress>(
    context: context,
    title: 'Link to a goal',
    subtitle: 'Optional - savings tagged with a goal count towards it.',
    options: goals,
    labelOf: (progress) => progress.name,
    iconOf: (progress) => AppIcons.resolve(progress.goal.iconKey),
    colorOf: (progress) => Color(progress.goal.colorValue),
    trailingOf: (progress) =>
        '${formatter.format(progress.saved)} of ${formatter.format(progress.target)}',
    isSelected: (progress) => progress.goal.id == selectedId,
    emptyState: const EmptyState(
      icon: Icons.flag_outlined,
      title: 'No savings goals yet',
      message: 'Create a goal to earmark savings towards it.',
      compact: true,
    ),
  ).then((progress) => progress?.goal);
}

/// Grid of the icons a category, account or goal can use.
Future<String?> showIconPicker({
  required BuildContext context,
  String? selectedKey,
  required Color accent,
}) {
  final keys = AppIcons.keys;
  return showAppSheet<String>(
    context: context,
    builder: (context) => AppSheet(
      title: 'Choose an icon',
      child: GridView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(Gap.lg),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 72,
          mainAxisSpacing: Gap.md,
          crossAxisSpacing: Gap.md,
        ),
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final key = keys[index];
          final selected = key == selectedKey;
          return InkWell(
            onTap: () => Navigator.of(context).pop(key),
            borderRadius: Corners.tile,
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.16)
                    : context.finance.cardElevated,
                borderRadius: Corners.tile,
                border: Border.all(
                  color: selected ? accent : context.finance.hairline,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Icon(
                AppIcons.resolve(key),
                color: selected ? accent : context.finance.textSecondary,
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Inline swatch row for choosing a colour.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.selectedValue,
    required this.onSelected,
  });

  final int selectedValue;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.md,
      children: AppPalette.swatches.map((value) {
        final color = Color(value);
        final selected = value == selectedValue;
        return Semantics(
          button: true,
          selected: selected,
          label: 'Colour option',
          child: InkWell(
            onTap: () => onSelected(value),
            borderRadius: BorderRadius.circular(Corners.pill),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? context.finance.textPrimary
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
