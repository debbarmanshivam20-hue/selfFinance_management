import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../analytics/analytics_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';
import 'add_button.dart';
import 'shell_providers.dart';

/// Root navigation.
///
/// Tabs are kept alive in an [IndexedStack] so switching back to the dashboard
/// does not re-run its queries or lose scroll position.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<_NavDestination> _destinations = <_NavDestination>[
    _NavDestination(
      label: 'Home',
      icon: Icons.space_dashboard_outlined,
      activeIcon: Icons.space_dashboard_rounded,
    ),
    _NavDestination(
      label: 'History',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
    ),
    _NavDestination(
      label: 'Analytics',
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
    ),
    _NavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: index,
        children: const <Widget>[
          DashboardScreen(),
          TransactionsScreen(),
          AnalyticsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        index: index,
        destinations: _destinations,
        onSelected: ref.read(shellTabProvider.notifier).select,
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Rounded floating navigation bar with the Add action raised in the middle.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.index,
    required this.destinations,
    required this.onSelected,
  });

  final int index;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: palette.cardElevated,
            borderRadius: BorderRadius.circular(Corners.xl),
            border: Border.all(color: palette.hairline),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: _tab(context, 0)),
              Expanded(child: _tab(context, 1)),
              const SizedBox(width: 72, child: Center(child: AddButton())),
              Expanded(child: _tab(context, 2)),
              Expanded(child: _tab(context, 3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int position) {
    final palette = context.finance;
    final theme = Theme.of(context);
    final destination = destinations[position];
    final selected = index == position;
    final color = selected ? theme.colorScheme.primary : palette.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onSelected(position),
        borderRadius: BorderRadius.circular(Corners.md),
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Motion.fast,
                child: Icon(
                  selected ? destination.activeIcon : destination.icon,
                  key: ValueKey<bool>(selected),
                  size: 23,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
