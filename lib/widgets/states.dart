import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failures.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import 'app_card.dart';

/// Shown wherever there is genuinely nothing to display yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Gap.xl,
          vertical: compact ? Gap.xl : Gap.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 76,
              height: compact ? 56 : 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.cardElevated,
                border: Border.all(color: palette.hairline),
              ),
              child: Icon(
                icon,
                size: compact ? 26 : 34,
                color: palette.textTertiary,
              ),
            ),
            SizedBox(height: compact ? Gap.md : Gap.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: compact
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.textTertiary),
            ),
            if (action != null) ...[
              const SizedBox(height: Gap.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly failure panel. It never renders the underlying exception - error
/// text in a finance app must not leak file paths or SQL.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      message: message,
      compact: compact,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, Touch.minTarget),
                foregroundColor: palette.textPrimary,
              ),
            ),
    );
  }
}

/// A neutral placeholder block used while a query is still running.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = Corners.xs,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(
              palette.hairline,
              palette.cardElevated,
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// Card-shaped loading placeholder.
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key, this.height = 120, this.lines = 3});

  final double height;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(height: 14, width: 120),
            const SizedBox(height: Gap.lg),
            for (var i = 0; i < lines; i++) ...[
              FractionallySizedBox(
                widthFactor: 1 - (i * 0.18).clamp(0.0, 0.6),
                alignment: Alignment.centerLeft,
                child: const SkeletonBox(height: 12),
              ),
              const SizedBox(height: Gap.sm),
            ],
          ],
        ),
      ),
    );
  }
}

/// List-shaped loading placeholder.
class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: AppCard(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                const SkeletonBox(height: 44, width: 44, radius: Corners.md),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(height: 13, width: 140),
                      SizedBox(height: Gap.sm),
                      SkeletonBox(height: 11, width: 90),
                    ],
                  ),
                ),
                const SkeletonBox(height: 15, width: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading and error treatments, so
/// every screen handles "still loading" and "it broke" the same way.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.loading,
    this.onRetry,
    this.compactError = true,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;
  final VoidCallback? onRetry;
  final bool compactError;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (data) => builder(context, data),
      loading: () => loading ?? const LoadingCard(),
      error: (error, _) => ErrorStateView(
        message: describeFailure(error),
        onRetry: onRetry,
        compact: compactError,
      ),
    );
  }
}
