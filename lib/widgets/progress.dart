import 'package:flutter/material.dart';

import '../core/constants/app_icons.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/utils/date_range.dart';
import '../core/utils/money.dart';
import '../models/analytics.dart';
import 'amount_text.dart';
import 'app_card.dart';

/// Colour for a budget's health. Health is also stated in words next to the
/// bar, so the colour is reinforcement rather than the only signal.
Color budgetHealthColor(BuildContext context, BudgetHealth health) {
  final palette = context.finance;
  return switch (health) {
    BudgetHealth.normal => palette.income,
    BudgetHealth.warning => palette.warning,
    BudgetHealth.critical => const Color(0xFFF97316),
    BudgetHealth.exceeded => palette.critical,
  };
}

/// Animated, rounded progress bar.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
    this.backgroundColor,
  });

  /// 0..1, already clamped by the caller.
  final double value;
  final Color color;
  final double height;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(
            height: height,
            color: backgroundColor ?? palette.hairline,
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: Motion.chart,
            curve: Motion.emphasized,
            builder: (context, animated, _) => FractionallySizedBox(
              widthFactor: animated,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.75), color],
                  ),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One budget, with spend, remaining and a health bar.
class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.status,
    required this.formatter,
    this.onTap,
  });

  final BudgetStatus status;
  final MoneyFormatter formatter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;
    final color = budgetHealthColor(context, status.health);
    final overspent = status.isOverspent;

    return AppCard(
      onTap: onTap,
      semanticLabel: '${status.name} budget. '
          '${formatter.format(status.spent)} spent of '
          '${formatter.format(status.limit)}. '
          '${status.percentUsed.toStringAsFixed(0)} percent used. '
          '${status.health.label}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: status.category == null
                    ? Icons.account_balance_wallet_rounded
                    : AppIcons.resolve(status.category!.iconKey),
                color: status.category == null
                    ? palette.textSecondary
                    : Color(status.category!.colorValue),
                size: 40,
                iconSize: 19,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatter.format(status.spent)} of ${formatter.format(status.limit)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: palette.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: Corners.chip,
                ),
                child: Text(
                  '${status.percentUsed.toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          ProgressTrack(value: status.progress, color: color),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Icon(
                overspent
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(
                  overspent
                      ? 'Over by ${formatter.format(status.spent - status.limit)}'
                      : '${formatter.format(status.remaining)} left · ${status.health.label}',
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!overspent && status.safeDailySpend != null)
                Text(
                  '${formatter.compact(status.safeDailySpend!)}/day',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: palette.textTertiary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One savings goal with a progress ring and the numbers behind it.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.progress,
    required this.formatter,
    this.onTap,
    this.onAddMoney,
  });

  final GoalProgress progress;
  final MoneyFormatter formatter;
  final VoidCallback? onTap;
  final VoidCallback? onAddMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;
    final color = Color(progress.goal.colorValue);
    final days = progress.daysRemaining;

    return AppCard(
      onTap: onTap,
      semanticLabel: '${progress.name} goal. '
          '${formatter.format(progress.saved)} saved of '
          '${formatter.format(progress.target)}. '
          '${progress.percent.toStringAsFixed(0)} percent complete.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GoalRing(
                progress: progress.progress,
                color: color,
                icon: AppIcons.resolve(progress.goal.iconKey),
                complete: progress.isComplete,
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            progress.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (progress.isComplete)
                          Icon(Icons.verified_rounded,
                              size: 18, color: palette.income),
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    AmountText(
                      money: progress.saved,
                      formatter: formatter,
                      size: 18,
                      showDecimals: false,
                      color: palette.textPrimary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress.isComplete
                          ? 'Target reached'
                          : '${formatter.format(progress.remaining, showDecimals: false)} to go of ${formatter.format(progress.target, showDecimals: false)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: palette.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          ProgressTrack(value: progress.progress, color: color, height: 7),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              if (progress.goal.targetDate != null) ...[
                Icon(Icons.event_rounded, size: 13, color: palette.textTertiary),
                const SizedBox(width: Gap.xs),
                Flexible(
                  child: Text(
                    days == null
                        ? DateLabels.medium.format(progress.goal.targetDate!)
                        : (days < 0
                            ? 'Target date passed'
                            : '$days days left'),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: palette.textTertiary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                Text(
                  '${progress.contributionCount} contribution${progress.contributionCount == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: palette.textTertiary),
                ),
              const Spacer(),
              if (onAddMoney != null && !progress.isComplete)
                TextButton.icon(
                  onPressed: onAddMoney,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add money'),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({
    required this.progress,
    required this.color,
    required this.icon,
    required this.complete,
  });

  final double progress;
  final Color color;
  final IconData icon;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: Motion.chart,
            curve: Motion.emphasized,
            builder: (context, value, _) => SizedBox(
              width: 58,
              height: 58,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                backgroundColor: palette.hairline,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          Icon(
            complete ? Icons.check_rounded : icon,
            size: 22,
            color: color,
          ),
        ],
      ),
    );
  }
}
