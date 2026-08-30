import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// The single place every colour, radius and text style is defined.
///
/// Widgets never hard-code a hex value: they read `Theme.of(context)` or the
/// [FinanceColors] extension, which is what keeps light and dark mode honest.
class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(FinanceColors.dark, Brightness.dark);

  static ThemeData light() => _build(FinanceColors.light, Brightness.light);

  static ThemeData _build(FinanceColors finance, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const seed = Color(0xFF10B981);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
      onPrimary: isDark ? const Color(0xFF04231A) : Colors.white,
      primaryContainer: isDark ? const Color(0xFF10362B) : const Color(0xFFD1FAE5),
      onPrimaryContainer: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF04231A),
      secondary: finance.savings,
      onSecondary: isDark ? const Color(0xFF04202E) : Colors.white,
      secondaryContainer: finance.savingsSoft,
      onSecondaryContainer: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF04202E),
      tertiary: finance.transfer,
      onTertiary: isDark ? const Color(0xFF1B1436) : Colors.white,
      tertiaryContainer: finance.transferSoft,
      onTertiaryContainer: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF2E1065),
      error: finance.critical,
      onError: isDark ? const Color(0xFF2B0A0A) : Colors.white,
      errorContainer: finance.expenseSoft,
      onErrorContainer: isDark ? const Color(0xFFFECACA) : const Color(0xFF7F1D1D),
      surface: finance.card,
      onSurface: finance.textPrimary,
      surfaceContainerLowest: finance.canvas,
      surfaceContainerLow: finance.card,
      surfaceContainer: finance.card,
      surfaceContainerHigh: finance.cardElevated,
      surfaceContainerHighest: finance.cardElevated,
      onSurfaceVariant: finance.textSecondary,
      outline: finance.hairline,
      outlineVariant: finance.hairline,
      shadow: finance.shadow,
      scrim: const Color(0xCC000000),
      inverseSurface: isDark ? finance.textPrimary : finance.canvas,
      onInverseSurface: isDark ? finance.canvas : finance.textPrimary,
      inversePrimary: seed,
    );

    final textTheme = AppType.textTheme(finance.textPrimary, finance.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: finance.canvas,
      canvasColor: finance.canvas,
      textTheme: textTheme,
      fontFamily: AppType.family,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[finance],

      appBarTheme: AppBarTheme(
        backgroundColor: finance.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: finance.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: finance.canvas,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: finance.canvas,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),

      cardTheme: CardThemeData(
        color: finance.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.card,
          side: BorderSide(color: finance.hairline),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: finance.hairline,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? finance.cardElevated : finance.canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: finance.textTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: finance.textSecondary),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: scheme.primary),
        prefixIconColor: finance.textSecondary,
        suffixIconColor: finance.textSecondary,
        errorStyle: textTheme.bodySmall?.copyWith(color: finance.critical),
        border: OutlineInputBorder(
          borderRadius: Corners.tile,
          borderSide: BorderSide(color: finance.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.tile,
          borderSide: BorderSide(color: finance.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Corners.tile,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Corners.tile,
          borderSide: BorderSide(color: finance.critical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Corners.tile,
          borderSide: BorderSide(color: finance.critical, width: 1.6),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Touch.minTarget + 4),
          shape: const RoundedRectangleBorder(borderRadius: Corners.tile),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(Touch.minTarget + 4),
          shape: const RoundedRectangleBorder(borderRadius: Corners.tile),
          side: BorderSide(color: finance.hairline),
          foregroundColor: finance.textPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(Touch.minTarget, Touch.minTarget),
          shape: const RoundedRectangleBorder(borderRadius: Corners.tile),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: finance.textSecondary,
          minimumSize: const Size(Touch.minTarget, Touch.minTarget),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? finance.cardElevated : finance.card,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: finance.hairline),
        labelStyle: textTheme.labelMedium!,
        secondaryLabelStyle: textTheme.labelMedium!,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
        shape: const RoundedRectangleBorder(borderRadius: Corners.chip),
        showCheckmark: false,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: finance.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: finance.card,
        shape: const RoundedRectangleBorder(borderRadius: Corners.sheet),
        showDragHandle: true,
        dragHandleColor: finance.hairline,
        clipBehavior: Clip.antiAlias,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: finance.cardElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Corners.card),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: finance.textSecondary),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: finance.cardElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: finance.textPrimary),
        actionTextColor: scheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Corners.tile),
        insetPadding: const EdgeInsets.all(Gap.lg),
        elevation: 6,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: finance.textSecondary,
        textColor: finance.textPrimary,
        shape: const RoundedRectangleBorder(borderRadius: Corners.tile),
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : finance.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : finance.hairline,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: finance.hairline,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: finance.hairline,
        circularTrackColor: finance.hairline,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: finance.textPrimary,
        unselectedLabelColor: finance.textTertiary,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: finance.cardElevated,
          borderRadius: Corners.tile,
          border: Border.all(color: finance.hairline),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: finance.textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
