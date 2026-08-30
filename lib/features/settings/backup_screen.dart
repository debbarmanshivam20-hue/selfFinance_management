import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../providers/core_providers.dart';
import '../../services/backup_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/dialogs.dart';

/// Local JSON export / import, and destructive data management.
///
/// Everything here operates on a file the user controls - the app never
/// uploads a backup anywhere. Sharing hands the file to the Android share
/// sheet so the user decides where it ends up.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).exportAndShare();
      if (!mounted) return;
      AppSnack.success(context, 'Backup ready to save or share');
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, describeFailure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final inspected = await service.inspect(File(path));
      if (!mounted) return;
      setState(() => _busy = false);

      final mode = await _pickImportMode(inspected.preview);
      if (mode == null || !mounted) return;

      final confirmed = await showConfirmDialog(
        context,
        title: mode == ImportMode.replace
            ? 'Replace everything?'
            : 'Import ${inspected.preview.totalRecords} records?',
        message: mode.description,
        confirmLabel: mode == ImportMode.replace ? 'Replace' : 'Import',
        destructive: mode == ImportMode.replace,
        icon: Icons.upload_file_rounded,
      );
      if (!confirmed || !mounted) return;

      setState(() => _busy = true);
      final report = await service.import(inspected.payload, mode);
      if (!mounted) return;
      AppSnack.success(context, report.summary);
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, describeFailure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ImportMode?> _pickImportMode(BackupPreview preview) {
    return showModalBottomSheet<ImportMode>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Backup file found',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Gap.sm),
              Text(
                '${preview.totalRecords} records'
                '${preview.exportedAt == null ? '' : ' · exported ${preview.exportedAt!.toLocal().toString().split('.').first}'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.finance.textTertiary),
              ),
              const SizedBox(height: Gap.xl),
              for (final mode in ImportMode.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(mode),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(Gap.lg),
                      alignment: Alignment.centerLeft,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mode.label,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          mode.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.finance.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAllTransactions() async {
    final confirmed = await showTypedConfirmDialog(
      context,
      title: 'Delete all transactions?',
      message:
          'Every income, expense, savings and transfer entry will be '
          'permanently removed. Categories, accounts, budgets and goals are '
          'kept. This cannot be undone.',
      requiredWord: 'DELETE',
      confirmLabel: 'Delete everything',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final removed =
          await ref.read(transactionRepositoryProvider).deleteAll();
      if (!mounted) return;
      AppSnack.success(context, 'Deleted $removed transaction${removed == 1 ? '' : 's'}');
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, describeFailure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final palette = context.finance;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Opacity(
          opacity: _busy ? 0.6 : 1,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                Gap.lg, Gap.lg, Gap.lg, Gap.huge),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(
                          icon: Icons.upload_outlined,
                          color: palette.income,
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Export a backup',
                                  style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                settings.lastBackupAt == null
                                    ? 'Never backed up'
                                    : 'Last backup ${settings.lastBackupAt!.toLocal()}'
                                        .split('.')
                                        .first,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: palette.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    Text(
                      'Saves everything - transactions, categories, accounts, '
                      'budgets and goals - into one JSON file you can store or '
                      'share anywhere.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                    const SizedBox(height: Gap.lg),
                    FilledButton.icon(
                      onPressed: _busy ? null : _export,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Export & share'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(
                          icon: Icons.download_outlined,
                          color: palette.savings,
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text('Import a backup',
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    Text(
                      'Choose a $_appBackupExtension file exported from this '
                      'app. You will be asked whether to merge it with what you '
                      'already have, or replace everything.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                    const SizedBox(height: Gap.lg),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _import,
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: const Text('Choose backup file'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.xl),
              const SectionHeader(title: 'Danger zone'),
              AppCard(
                borderColor: palette.critical.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(
                          icon: Icons.delete_forever_outlined,
                          color: palette.critical,
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text('Delete all transactions',
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    Text(
                      'Permanently removes every recorded transaction. '
                      'Categories, accounts, budgets and goals are kept. '
                      'Export a backup first if you might need this data again.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                    const SizedBox(height: Gap.lg),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _deleteAllTransactions,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete all transactions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.critical,
                        side: BorderSide(
                            color: palette.critical.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const String _appBackupExtension = '.json';
}
