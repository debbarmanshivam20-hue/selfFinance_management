import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_icons.dart';
import '../../core/database/app_database.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../models/enums.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/pickers.dart';
import '../../widgets/states.dart';

/// CRUD screen for the categories transactions are filed under.
class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: CategoryKind.values.length, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: CategoryKind.values
              .map((kind) => Tab(text: kind.label))
              .toList(growable: false),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: CategoryKind.values
            .map((kind) => _CategoryList(kind: kind))
            .toList(growable: false),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, kind: _currentKind),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
    );
  }

  CategoryKind get _currentKind => CategoryKind.values[_tabController.index];

  static Future<void> _openEditor(
    BuildContext context, {
    required CategoryKind kind,
    CategoryRow? existing,
  }) {
    return showAppSheet<void>(
      context: context,
      builder: (context) => _CategoryEditorSheet(kind: kind, existing: existing),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.kind});

  final CategoryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesByKindProvider(kind));

    return AsyncView<List<CategoryRow>>(
      value: categories,
      builder: (context, items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.category_outlined,
            title: 'No ${kind.label.toLowerCase()} categories',
            message: 'Add one with the button below.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
          itemBuilder: (context, index) {
            final category = items[index];
            return AppCard(
              padding: const EdgeInsets.all(Gap.md),
              onTap: () => _ManageCategoriesScreenState._openEditor(
                context,
                kind: kind,
                existing: category,
              ),
              child: Row(
                children: [
                  IconBadge(
                    icon: AppIcons.resolve(category.iconKey),
                    color: Color(category.colorValue),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (category.isSystem)
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
    );
  }
}

class _CategoryEditorSheet extends ConsumerStatefulWidget {
  const _CategoryEditorSheet({required this.kind, this.existing});

  final CategoryKind kind;
  final CategoryRow? existing;

  @override
  ConsumerState<_CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<_CategoryEditorSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _iconKey = widget.existing?.iconKey ?? 'category';
  late int _colorValue =
      widget.existing?.colorValue ?? AppPalette.at(widget.kind.index);
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnack.error(context, 'Give the category a name.');
      return;
    }
    setState(() => _saving = true);
    try {
      final actions = ref.read(categoryActionsProvider);
      if (_isEditing) {
        await actions.update(
          widget.existing!,
          name: name,
          iconKey: _iconKey,
          colorValue: _colorValue,
        );
      } else {
        await actions.create(
          name: name,
          kind: widget.kind,
          iconKey: _iconKey,
          colorValue: _colorValue,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(context, _isEditing ? 'Category updated' : 'Category added');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(context, describeFailure(error));
    }
  }

  Future<void> _delete() async {
    final category = widget.existing!;
    final usage = await ref.read(categoryActionsProvider).usageCount(category.id);
    if (!mounted) return;

    final message = usage == 0
        ? 'This category will be removed.'
        : category.isSystem
            ? 'This is a default category, so it will be hidden instead of '
                'deleted. $usage existing transaction${usage == 1 ? '' : 's'} '
                'will keep showing it.'
            : '$usage transaction${usage == 1 ? '' : 's'} using this category '
                'will become uncategorised.';

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "${category.name}"?',
      message: message,
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(categoryActionsProvider).delete(category);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(context, 'Category deleted');
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, describeFailure(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_colorValue);

    return AppSheet(
      title: _isEditing ? 'Edit category' : 'New ${widget.kind.label.toLowerCase()} category',
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
              hint: 'e.g. Groceries',
              required: true,
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
              child: Text(_isEditing ? 'Save changes' : 'Add category'),
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
