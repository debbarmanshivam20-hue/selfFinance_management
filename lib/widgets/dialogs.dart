import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';

/// Yes/no confirmation. Returns `true` only when the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final palette = context.finance;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: icon == null
          ? null
          : Icon(
              icon,
              color: destructive ? palette.critical : palette.textSecondary,
            ),
      title: Text(title),
      content: Text(message),
      actionsPadding:
          const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: palette.critical,
                  foregroundColor: Colors.white,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Confirmation that requires typing a word, for irreversible actions.
Future<bool> showTypedConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String requiredWord,
  String confirmLabel = 'Delete everything',
}) async {
  final controller = TextEditingController();
  final palette = context.finance;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final matches = controller.text.trim().toUpperCase() == requiredWord;
        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: palette.critical),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: Gap.lg),
              TextField(
                controller: controller,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: requiredWord,
                  labelText: 'Type $requiredWord to confirm',
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: matches
                  ? () => Navigator.of(context).pop(true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: palette.critical,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );

  controller.dispose();
  return result ?? false;
}

/// Themed snackbars. Kept in one place so success and failure always look the
/// same wherever they are raised.
class AppSnack {
  AppSnack._();

  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_rounded,
          context.finance.income);

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_outline_rounded,
          context.finance.critical);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_outline_rounded,
          context.finance.textSecondary);

  static void action(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
  }

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: Gap.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
