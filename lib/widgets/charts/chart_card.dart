import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../app_card.dart';

/// Standard frame for every chart: title, optional control, fixed height body.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.height = 220,
    this.legend,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final double height;
  final Widget? legend;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: Gap.xxs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: palette.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Gap.sm),
                trailing!,
              ],
            ],
          ),
          if (legend != null) ...[
            const SizedBox(height: Gap.md),
            legend!,
          ],
          const SizedBox(height: Gap.lg),
          SizedBox(height: height, child: child),
          if (footer != null) ...[
            const SizedBox(height: Gap.md),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// A single entry in a chart legend.
class LegendDot extends StatelessWidget {
  const LegendDot({
    super.key,
    required this.color,
    required this.label,
    this.value,
  });

  final Color color;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Gap.sm),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: palette.textSecondary),
        ),
        if (value != null) ...[
          const SizedBox(width: Gap.xs),
          Text(value!, style: theme.textTheme.labelSmall?.copyWith(color: color)),
        ],
      ],
    );
  }
}

/// Legend row that wraps rather than overflowing on narrow screens.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.lg,
      runSpacing: Gap.sm,
      children: items,
    );
  }
}

/// Shown inside a [ChartCard] when there is no data to plot. A chart with no
/// data must never render as a broken or empty axis.
class ChartEmpty extends StatelessWidget {
  const ChartEmpty({
    super.key,
    required this.message,
    this.icon = Icons.bar_chart_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: palette.textTertiary),
          const SizedBox(height: Gap.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
