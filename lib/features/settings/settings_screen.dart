import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_card.dart';
import '../budgets/budgets_screen.dart';
import '../goals/goals_screen.dart';
import 'backup_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_payment_methods_screen.dart';

/// App preferences, data management, and everything else that is not a
/// day-to-day transaction task.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.navClearance),
        children: [
          const SectionHeader(title: 'Appearance'),
          AppCard(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Theme', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: Gap.md),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_rounded, size: 16),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .setThemeMode(value.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),

          const SectionHeader(title: 'Money'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.currency_exchange_rounded,
                  title: 'Currency',
                  value: '${settings.currency.name} (${settings.currency.symbol})',
                  onTap: () => _showCurrencyPicker(context, ref),
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.event_repeat_rounded,
                  title: 'Financial month starts on',
                  value: 'Day ${settings.monthStartDay}',
                  onTap: () => _showMonthStartPicker(context, ref),
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.category_outlined,
                  title: 'Categories',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ManageCategoriesScreen()),
                  ),
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Accounts & payment methods',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ManagePaymentMethodsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),

          const SectionHeader(title: 'Budgets & goals'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'Manage budgets',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const BudgetsScreen()),
                  ),
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.flag_outlined,
                  title: 'Manage savings goals',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const GoalsScreen()),
                  ),
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.tune_rounded,
                  title: 'Budget alert thresholds',
                  value: '${settings.budgetWarningThreshold.round()}% / '
                      '${settings.budgetCriticalThreshold.round()}%',
                  onTap: () => _showThresholdEditor(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),

          const SectionHeader(title: 'Your data'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.backup_outlined,
                  title: 'Backup & restore',
                  subtitle: settings.lastBackupAt == null
                      ? 'Never backed up'
                      : 'Last backup ${_relativeBackup(settings.lastBackupAt!)}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),

          const SectionHeader(title: 'About'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: Icons.account_balance_wallet_rounded,
                      color: context.finance.income,
                    ),
                    const SizedBox(width: Gap.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppInfo.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('Version ${AppInfo.version}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: context.finance.textTertiary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Text(
                  AppInfo.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.finance.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeBackup(DateTime at) {
    final days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).currencyCode;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: RadioGroup<String>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) {
              ref.read(settingsProvider.notifier).setCurrency(value);
            }
            Navigator.of(context).pop();
          },
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: Gap.md),
            children: [
              for (final currency in SupportedCurrencies.all)
                RadioListTile<String>(
                  value: currency.code,
                  title: Text('${currency.name} (${currency.symbol})'),
                  subtitle: Text(currency.code),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthStartPicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).monthStartDay;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 280,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Text(
                  'Financial month starts on',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: Gap.sm,
                    crossAxisSpacing: Gap.sm,
                  ),
                  itemCount: 28,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final selected = day == current;
                    return InkWell(
                      onTap: () {
                        ref.read(settingsProvider.notifier).setMonthStartDay(day);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(Corners.sm),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? context.finance.savings.withValues(alpha: 0.16)
                              : context.finance.cardElevated,
                          borderRadius: BorderRadius.circular(Corners.sm),
                          border: Border.all(
                            color: selected
                                ? context.finance.savings
                                : context.finance.hairline,
                          ),
                        ),
                        child: Text('$day'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: Gap.lg),
            ],
          ),
        ),
      ),
    );
  }

  void _showThresholdEditor(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    var warning = settings.budgetWarningThreshold;
    var critical = settings.budgetCriticalThreshold;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Budget alert thresholds',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: Gap.xs),
                Text(
                  'Choose when a budget switches from "on track" to "watch" '
                  'to "almost gone".',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.finance.textTertiary),
                ),
                const SizedBox(height: Gap.xl),
                Text('Watch at ${warning.round()}% used'),
                Slider(
                  value: warning,
                  min: 10,
                  max: critical - 5,
                  divisions: ((critical - 5 - 10) / 5).round().clamp(1, 100),
                  label: '${warning.round()}%',
                  onChanged: (value) => setState(() => warning = value),
                ),
                Text('Almost gone at ${critical.round()}% used'),
                Slider(
                  value: critical,
                  min: warning + 5,
                  max: 100,
                  divisions: ((100 - warning - 5) / 5).round().clamp(1, 100),
                  label: '${critical.round()}%',
                  onChanged: (value) => setState(() => critical = value),
                ),
                const SizedBox(height: Gap.lg),
                FilledButton(
                  onPressed: () {
                    ref.read(settingsProvider.notifier).setBudgetThresholds(
                          warning: warning,
                          critical: critical,
                        );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: palette.textSecondary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: palette.textTertiary),
            ),
          if (onTap != null) ...[
            const SizedBox(width: Gap.xs),
            Icon(Icons.chevron_right_rounded, color: palette.textTertiary),
          ],
        ],
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: Gap.lg + 24 + Gap.md,
      color: context.finance.hairline,
    );
  }
}
