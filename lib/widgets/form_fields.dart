import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/date_range.dart';
import '../core/utils/money.dart';

/// Label above a form control.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm, left: Gap.xxs),
      child: Row(
        children: [
          Text(
            text,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: palette.textSecondary),
          ),
          if (required)
            Text(
              ' *',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: palette.expense),
            ),
        ],
      ),
    );
  }
}

/// The large amount entry at the top of the Add Transaction screen.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.symbol,
    required this.accent,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String symbol;
  final Color accent;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;

    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        // Digits plus at most one decimal separator with up to two places.
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        _DecimalInputFormatter(),
      ],
      style: AppType.display(40).copyWith(color: accent),
      cursorColor: accent,
      decoration: InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        hintText: '0',
        hintStyle: AppType.display(40)
            .copyWith(color: palette.textTertiary.withValues(alpha: 0.4)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: Gap.lg, right: Gap.xs),
          child: Text(
            symbol,
            style: AppType.display(26).copyWith(color: accent),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(vertical: Gap.sm),
      ),
      validator: (value) {
        final money = Money.tryParse(value ?? '');
        if (money == null || money.minor <= 0) {
          return 'Enter an amount greater than zero';
        }
        return null;
      },
    );
  }
}

/// Keeps amount input to a single separator and two decimal places.
class _DecimalInputFormatter extends TextInputFormatter {
  static final RegExp _valid = RegExp(r'^\d*([.,]\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    return _valid.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

/// Standard labelled text input.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.sentences,
    this.validator,
    this.required = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? icon;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final bool required;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) FieldLabel(label!, required: required),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          validator: validator,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon, size: 20),
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// A tappable field that shows the current selection and opens a picker.
class SelectorField extends StatelessWidget {
  const SelectorField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.placeholder = 'Select',
    this.required = false,
    this.errorText,
    this.trailing,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final String placeholder;
  final bool required;
  final String? errorText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.finance;
    final hasValue = value != null && value!.isNotEmpty;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, required: required),
        Semantics(
          button: true,
          label: '$label. ${hasValue ? value! : placeholder}',
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: Corners.tile,
              child: Container(
                constraints:
                    const BoxConstraints(minHeight: Touch.minTarget + 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md,
                ),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? palette.cardElevated
                      : palette.canvas,
                  borderRadius: Corners.tile,
                  border: Border.all(
                    color: hasError ? palette.critical : palette.hairline,
                  ),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 20,
                        color: iconColor ?? palette.textSecondary,
                      ),
                      const SizedBox(width: Gap.md),
                    ],
                    Expanded(
                      child: Text(
                        hasValue ? value! : placeholder,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: hasValue
                              ? palette.textPrimary
                              : palette.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing ??
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: palette.textTertiary,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs, left: Gap.md),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(color: palette.critical),
            ),
          ),
      ],
    );
  }
}

/// Date field backed by the platform date picker.
class DateSelectorField extends StatelessWidget {
  const DateSelectorField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Date',
    this.firstDate,
    this.lastDate,
    this.allowClear = false,
    this.placeholder = 'Select a date',
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool allowClear;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;
    return SelectorField(
      label: label,
      icon: Icons.event_rounded,
      placeholder: placeholder,
      value: value == null ? null : DateLabels.full.format(value!),
      trailing: allowClear && value != null
          ? IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => onChanged(null),
              tooltip: 'Clear date',
              visualDensity: VisualDensity.compact,
              color: palette.textTertiary,
            )
          : null,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: firstDate ?? DateTime(now.year - 10),
          lastDate: lastDate ?? DateTime(now.year + 10),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
