import 'package:flutter/material.dart';

/// Typography built on the bundled Inter variable font.
///
/// The font ships inside the APK, so there is no network fetch at runtime -
/// a hard requirement for a fully offline app. Weight is applied through
/// [FontVariation] on the `wght` axis (as well as [FontWeight]) so the
/// variable font renders true weights on every engine version.
class AppType {
  AppType._();

  static const String family = 'Inter';

  static TextStyle _style({
    required double size,
    required double weight,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: _toFontWeight(weight),
      fontVariations: <FontVariation>[FontVariation('wght', weight)],
    );
  }

  static FontWeight _toFontWeight(double weight) {
    final index = ((weight / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }

  /// Large numeric readouts (balance hero). Tight tracking reads as premium.
  static TextStyle display(double size) =>
      _style(size: size, weight: 700, height: 1.05, letterSpacing: -1.0);

  static TextStyle amount(double size, {double weight = 700}) =>
      _style(size: size, weight: weight, height: 1.15, letterSpacing: -0.4);

  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: _style(size: 40, weight: 700, height: 1.06, letterSpacing: -1.2),
      displayMedium: _style(size: 34, weight: 700, height: 1.08, letterSpacing: -1.0),
      displaySmall: _style(size: 28, weight: 700, height: 1.12, letterSpacing: -0.8),
      headlineLarge: _style(size: 26, weight: 700, height: 1.2, letterSpacing: -0.6),
      headlineMedium: _style(size: 22, weight: 700, height: 1.24, letterSpacing: -0.4),
      headlineSmall: _style(size: 20, weight: 600, height: 1.28, letterSpacing: -0.3),
      titleLarge: _style(size: 18, weight: 600, height: 1.3, letterSpacing: -0.2),
      titleMedium: _style(size: 16, weight: 600, height: 1.35, letterSpacing: -0.1),
      titleSmall: _style(size: 14, weight: 600, height: 1.4),
      bodyLarge: _style(size: 16, weight: 400, height: 1.5),
      bodyMedium: _style(size: 14, weight: 400, height: 1.5),
      bodySmall: _style(size: 12.5, weight: 400, height: 1.45),
      labelLarge: _style(size: 14, weight: 600, height: 1.3, letterSpacing: 0.1),
      labelMedium: _style(size: 12.5, weight: 600, height: 1.3, letterSpacing: 0.2),
      labelSmall: _style(size: 11, weight: 600, height: 1.3, letterSpacing: 0.4),
    ).apply(bodyColor: primary, displayColor: primary);
  }
}
